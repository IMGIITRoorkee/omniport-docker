#!/bin/bash

# Channel-i Security Fixes - Deployment Testing Script
#
# Verifies the four fixes in this wave against a running deployment:
#
#   F-NEW-15  omniport-docker#58        Redis Commander removed
#   F-NEW-16  omniport-docker#59        Content Security Policy scoped
#   F-7       omniport-app-noticeboard#27  Notices require authentication
#   F-NEW-12  omniport-backend#229      Pillow past CVE-2023-50447
#
# Usage: ./test_security_fixes.sh https://staging.channel.iitr.ac.in
# Or:    ./test_security_fixes.sh http://localhost:8000
#
# Optional, to also check that a logged-in caller still sees notices:
#   SESSION_COOKIE='sessionid=<value>' ./test_security_fixes.sh <url>
#
# Optional, to name the compose service running Django for the Pillow check:
#   DJANGO_SERVICE=intranet-server ./test_security_fixes.sh <url>
#
# Run a single section:  ./test_security_fixes.sh <url> redis|csp|noticeboard|pillow

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Get base URL from argument
BASE_URL="${1:-http://localhost:8000}"
BASE_URL="${BASE_URL%/}"
SECTION="${2:-all}"

# The host on its own, for the port checks
HOST=$(echo "$BASE_URL" | sed -E 's#^[a-zA-Z]+://##; s#[:/].*$##')

# Compose service running Django, for the Pillow check
DJANGO_SERVICE="${DJANGO_SERVICE:-intranet-server}"

# Test counters
PASSED=0
FAILED=0
WARNINGS=0

# Helper functions
print_header() {
    echo -e "\n${BLUE}${BOLD}================================================${NC}"
    echo -e "${BLUE}${BOLD}$1${NC}"
    echo -e "${BLUE}${BOLD}================================================${NC}\n"
}

print_test() {
    echo -e "${BOLD}TEST:${NC} $1"
}

pass() {
    echo -e "  ${GREEN}✓ PASS${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "  ${RED}✗ FAIL${NC} $1"
    ((FAILED++))
}

warn() {
    echo -e "  ${YELLOW}⚠ WARN${NC} $1"
    ((WARNINGS++))
}

# Return the response headers for a path
headers_for() {
    curl -s -D - -o /dev/null --max-time 15 "$BASE_URL$1" 2>/dev/null
}

# Is a response really from the API, or the frontend bundle answering for a
# path NGINX never routes to Django? An SPA fallback is 200 text/html, so a
# status code on its own cannot tell a working endpoint from a missing one.
is_json_response() {
    local path="$1"
    curl -s -o /dev/null -w '%{content_type}' --max-time 20 \
        "$BASE_URL$path" 2>/dev/null | grep -qi 'application/json'
}

# Return the status code for a path, with no credentials of any kind
anonymous_status() {
    curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$BASE_URL$1" 2>/dev/null
}

# Is a TCP port open on the host?
port_is_open() {
    local port="$1"
    curl -s -o /dev/null --max-time 5 "http://$HOST:$port/" 2>/dev/null
    local code=$?
    # 0 spoke HTTP, 52 empty reply, 56 reset mid-read: all mean something
    # answered. 7 is connection refused and 28 is a timeout, which are what a
    # closed or filtered port looks like.
    case $code in
        0|52|56) return 0 ;;
        *)       return 1 ;;
    esac
}

# Obtain a session by logging in, when credentials are supplied. Saves pasting
# a cookie out of a browser, which is not always possible for whoever is
# running this.
obtain_session() {
    if [ -n "$SESSION_COOKIE" ]; then
        return 0
    fi
    if [ -z "$STAGING_USER" ] || [ -z "$STAGING_PASSWORD" ]; then
        return 1
    fi

    local jar token session
    jar=$(mktemp)

    curl -s -o /dev/null -c "$jar" --max-time 20 \
        "$BASE_URL/ensure_csrf/" 2>/dev/null
    token=$(awk '$6 == "csrftoken" {print $7}' "$jar" | tail -1)

    curl -s -o /dev/null -b "$jar" -c "$jar" --max-time 20 \
        -H "Content-Type: application/json" \
        -H "X-CSRFToken: $token" \
        -H "Referer: $BASE_URL/" \
        -d "{\"username\": \"$STAGING_USER\", \"password\": \"$STAGING_PASSWORD\"}" \
        "$BASE_URL/session_auth/login/" 2>/dev/null

    session=$(awk '$6 == "sessionid" {print $7}' "$jar" | tail -1)
    rm -f "$jar"

    if [ -n "$session" ]; then
        SESSION_COOKIE="sessionid=$session"
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# F-NEW-15 - omniport-docker#58 - Redis Commander removed
# ---------------------------------------------------------------------------
test_redis_commander_removed() {
    print_header "F-NEW-15: Redis Commander must not be reachable"
    print_test "Port 8081 must not answer on $HOST"

    if port_is_open 8081; then
        fail "something is answering on $HOST:8081"
        echo -e "      ${RED}This is the unauthenticated Redis console. It has"
        echo -e "      read/write over the session store, so this is session"
        echo -e "      hijacking for every logged-in user.${NC}"
        body=$(curl -s --max-time 5 "http://$HOST:8081/" 2>/dev/null | head -c 200)
        if echo "$body" | grep -qi "redis"; then
            echo -e "      ${RED}Response mentions Redis, so it is the console itself.${NC}"
        fi
    else
        pass "nothing answers on $HOST:8081"
    fi

    print_test "The Redis and PostgreSQL ports must not be published either"

    for port in 6379 5432; do
        if port_is_open "$port"; then
            fail "$HOST:$port is reachable from here"
        else
            pass "$HOST:$port is not reachable from here"
        fi
    done

    echo -e "\n  ${YELLOW}Note:${NC} run this from a machine on the campus network,"
    echo -e "  not from the server itself. A port bound to the host is closed"
    echo -e "  to the outside but still open to localhost, so testing on the"
    echo -e "  box can miss what this finding is about."
}

# ---------------------------------------------------------------------------
# F-NEW-16 - omniport-docker#59 - Content Security Policy scoped
# ---------------------------------------------------------------------------
test_content_security_policy() {
    print_header "F-NEW-16: Content Security Policy must name its origins"

    all_headers=$(headers_for "/")
    csp=$(echo "$all_headers" | grep -i "^content-security-policy:" | head -1 | \
          sed -E 's/^[Cc]ontent-[Ss]ecurity-[Pp]olicy:[[:space:]]*//' | tr -d '\r')

    print_test "The header is present"
    if [ -z "$csp" ]; then
        fail "no Content-Security-Policy header on $BASE_URL/"
        return
    fi
    pass "present"
    echo -e "      ${BOLD}Policy:${NC} $csp"

    print_test "The header is sent exactly once"
    count=$(echo "$all_headers" | grep -ci "^content-security-policy:")
    if [ "$count" -eq 1 ]; then
        pass "sent once"
    else
        fail "sent $count times; NGINX add_header appends rather than replaces"
    fi

    print_test "No directive allows every origin"
    wildcard_found=0
    for directive in default-src script-src connect-src frame-src object-src base-uri form-action; do
        sources=$(echo "$csp" | tr ';' '\n' | grep -E "^[[:space:]]*$directive[[:space:]]" | head -1)
        if echo "$sources" | grep -qE '(^|[[:space:]])\*([[:space:]]|$)'; then
            fail "$directive allows every origin"
            wildcard_found=1
        fi
    done
    if [ "$wildcard_found" -eq 0 ]; then
        pass "no * source in the directives that matter"
    fi

    print_test "default-src falls back to 'self'"
    if echo "$csp" | tr ';' '\n' | grep -qE "^[[:space:]]*default-src[[:space:]]+'self'[[:space:]]*$"; then
        pass "default-src 'self'"
    else
        fail "default-src is not exactly 'self'"
    fi

    print_test "The directives with nothing to lose are set"
    for pair in "object-src:'none'" "base-uri:'self'" "form-action:'self'" "frame-ancestors:'self'"; do
        directive="${pair%%:*}"
        expected="${pair#*:}"
        if echo "$csp" | tr ';' '\n' | grep -qE "^[[:space:]]*$directive[[:space:]]+$expected[[:space:]]*$"; then
            pass "$directive $expected"
        else
            fail "$directive is not $expected"
        fi
    done

    print_test "Static responses carry the policy too"
    static_csp=$(headers_for "/static/favicon.ico" | grep -ci "^content-security-policy:")
    if [ "$static_csp" -ge 1 ]; then
        pass "a static response carries it"
    else
        warn "no policy on /static/favicon.ico; if that path 404s this is not"
        warn "meaningful, but check a real asset URL by hand"
    fi

    print_test "The other security headers are each sent once"
    for header in x-frame-options x-content-type-options referrer-policy strict-transport-security; do
        n=$(echo "$all_headers" | grep -ci "^$header:")
        if [ "$n" -eq 1 ]; then
            pass "$header sent once"
        elif [ "$n" -eq 0 ]; then
            warn "$header not present"
        else
            fail "$header sent $n times"
        fi
    done
}

# ---------------------------------------------------------------------------
# F-7 - omniport-app-noticeboard#27 - Notices require authentication
# ---------------------------------------------------------------------------
test_noticeboard_requires_authentication() {
    print_header "F-7: Notices must not be readable without an account"

    print_test "Every notice route refuses an anonymous caller"

    routes=(
        "/api/noticeboard/new/"
        "/api/noticeboard/old/"
        "/api/noticeboard/filter_list/"
        "/api/noticeboard/filter/"
        "/api/noticeboard/date_filter_view/"
        "/api/noticeboard/institute_notices/"
        "/api/noticeboard/star_filter_view/"
    )

    for route in "${routes[@]}"; do
        code=$(anonymous_status "$route")
        if ! is_json_response "$route"; then
            warn "$route -> HTTP $code but not application/json, so this is the"
            warn "frontend bundle answering rather than the API. The route is"
            warn "not mounted here and this check proved nothing."
            continue
        fi
        case "$code" in
            401|403)
                pass "$route -> HTTP $code"
                ;;
            200)
                fail "$route -> HTTP 200, readable with no account"
                count=$(curl -s --max-time 15 "$BASE_URL$route" 2>/dev/null | \
                        grep -o '"count":[0-9]*' | head -1)
                if [ -n "$count" ]; then
                    echo -e "      ${RED}Returned $count${NC}"
                fi
                ;;
            000)
                warn "$route -> could not reach the server"
                ;;
            *)
                warn "$route -> HTTP $code, neither 200 nor 401/403"
                ;;
        esac
    done

    print_test "A specific notice is not readable by id"
    code=$(anonymous_status "/api/noticeboard/new/1/")
    if [ "$code" == "401" ] || [ "$code" == "403" ]; then
        pass "/api/noticeboard/new/1/ -> HTTP $code"
    elif [ "$code" == "404" ]; then
        warn "/api/noticeboard/new/1/ -> HTTP 404; no notice with that id, so"
        warn "this proves nothing. Re-run with an id that exists."
    else
        fail "/api/noticeboard/new/1/ -> HTTP $code"
    fi

    if [ -n "$SESSION_COOKIE" ]; then
        print_test "A logged-in caller still sees notices"
        code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 \
               -H "Cookie: $SESSION_COOKIE" "$BASE_URL/api/noticeboard/new/" 2>/dev/null)
        if [ "$code" == "200" ]; then
            pass "authenticated GET /api/noticeboard/new/ -> HTTP 200"
        else
            fail "authenticated GET /api/noticeboard/new/ -> HTTP $code; the fix"
            fail "has locked out legitimate users, which is worse than the finding"
        fi
    else
        warn "SESSION_COOKIE not set, so the authenticated path was not checked."
        warn "Half of this fix is that logged-in people still see everything."
        warn "Re-run as: SESSION_COOKIE='sessionid=<value>' $0 $BASE_URL"
    fi
}

# ---------------------------------------------------------------------------
# F-NEW-12 - omniport-backend#229 - Pillow past CVE-2023-50447
# ---------------------------------------------------------------------------
test_pillow_version() {
    print_header "F-NEW-12: Pillow must be at 10.2.0 or later"

    print_test "The installed version is past the advisory"

    version=""
    if command -v docker > /dev/null 2>&1; then
        version=$(docker compose exec -T "$DJANGO_SERVICE" \
                  python -c "import PIL; print(PIL.__version__)" 2>/dev/null | tr -d '\r')
        if [ -z "$version" ]; then
            version=$(docker exec "$DJANGO_SERVICE" \
                      python -c "import PIL; print(PIL.__version__)" 2>/dev/null | tr -d '\r')
        fi
    fi

    if [ -z "$version" ]; then
        warn "could not read the installed Pillow version from here."
        warn "This one is a dependency pin, so there is no endpoint that"
        warn "reveals it. Run this on the server instead:"
        echo -e "\n      ${BOLD}docker compose exec $DJANGO_SERVICE \\"
        echo -e "        python -c 'import PIL; print(PIL.__version__)'${NC}\n"
        echo -e "      Anything below 10.2.0 is covered by CVE-2023-50447."
        return
    fi

    echo -e "      ${BOLD}Installed:${NC} Pillow $version"

    major=$(echo "$version" | cut -d. -f1)
    minor=$(echo "$version" | cut -d. -f2)

    if [ "$major" -gt 10 ] 2>/dev/null; then
        pass "Pillow $version is past the advisory"
    elif [ "$major" -eq 10 ] && [ "$minor" -ge 2 ] 2>/dev/null; then
        pass "Pillow $version is past the advisory"
    else
        fail "Pillow $version is covered by CVE-2023-50447"
        echo -e "      ${RED}The advisory covers every release through 10.1.0."
        echo -e "      First patched release is 10.2.0.${NC}"
    fi
}

# Print summary
print_summary() {
    print_header "SUMMARY"

    total=$((PASSED + FAILED))
    if [ $total -gt 0 ]; then
        percentage=$((PASSED * 100 / total))
    else
        percentage=0
    fi

    echo -e "${BOLD}Total Tests:${NC} $total"
    echo -e "${GREEN}${BOLD}Passed:${NC} $PASSED"
    echo -e "${RED}${BOLD}Failed:${NC} $FAILED"
    echo -e "${YELLOW}${BOLD}Warnings:${NC} $WARNINGS"
    echo -e "${BOLD}Pass Rate:${NC} $percentage%"

    if [ $WARNINGS -gt 0 ]; then
        echo -e "\n${YELLOW}Warnings are checks that did not run, not checks that"
        echo -e "passed. Read them before treating this as a clean result.${NC}"
    fi

    if [ $total -eq 0 ]; then
        echo -e "\n${YELLOW}${BOLD}⚠ NO CHECKS RAN${NC}"
        echo -e "${YELLOW}Every check was skipped, so nothing was verified. That is"
        echo -e "not a pass, and this exits non-zero so a pipeline cannot read it"
        echo -e "as one.${NC}\n"
        return 1
    fi

    if [ $FAILED -eq 0 ]; then
        echo -e "\n${GREEN}${BOLD}✓ ALL TESTS PASSED!${NC}"
        echo -e "${GREEN}Security fixes are working correctly${NC}\n"
        return 0
    else
        echo -e "\n${RED}${BOLD}✗ $FAILED TEST(S) FAILED${NC}"
        echo -e "${RED}Please review the failures above${NC}\n"
        return 1
    fi
}

# Main
main() {
    echo -e "${BOLD}${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║     Channel-i Security Fixes - Deployment Tests                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "${BOLD}Testing against:${NC} $BASE_URL"
    echo -e "${BOLD}Host for port checks:${NC} $HOST"
    echo -e "${BOLD}Section:${NC} $SECTION\n"

    # Validate the section before reaching for the network, so that a typo
    # reports itself rather than being reported as an unreachable server
    case "$SECTION" in
        redis|csp|noticeboard|pillow|all) ;;
        *)
            echo -e "${RED}Unknown section: $SECTION${NC}"
            echo -e "${YELLOW}Use one of: redis, csp, noticeboard, pillow, all${NC}\n"
            exit 1
            ;;
    esac

    # Check if server is reachable
    if ! curl -s -o /dev/null --max-time 15 "$BASE_URL/kernel/who_am_i/" 2>/dev/null; then
        if ! curl -s -o /dev/null --max-time 15 "$BASE_URL/" 2>/dev/null; then
            echo -e "${RED}ERROR: Cannot reach server at $BASE_URL${NC}"
            echo -e "${YELLOW}Make sure the server is running and URL is correct${NC}\n"
            exit 1
        fi
    fi

    if obtain_session; then
        if [ -n "$STAGING_USER" ]; then
            echo -e "${BOLD}Session:${NC} obtained by logging in as $STAGING_USER\n"
        fi
    elif [ -n "$STAGING_USER" ]; then
        echo -e "${YELLOW}Could not log in as $STAGING_USER; authenticated checks"
        echo -e "will be skipped. Check the credentials and that"
        echo -e "$BASE_URL/session_auth/login/ is reachable.${NC}\n"
    fi

    case "$SECTION" in
        redis)       test_redis_commander_removed ;;
        csp)         test_content_security_policy ;;
        noticeboard) test_noticeboard_requires_authentication ;;
        pillow)      test_pillow_version ;;
        all)
            test_redis_commander_removed
            test_content_security_policy
            test_noticeboard_requires_authentication
            test_pillow_version
            ;;
    esac

    print_summary
}

# Run main
main
