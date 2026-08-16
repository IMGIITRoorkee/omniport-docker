#!/bin/bash

# Channel-i Security PRs - Staging Verification Script
#
# Checks the fix wave against a running deployment, one section per pull
# request. Sections are named after the PR they verify:
#
#   groups-8            IMGIITRoorkee/omniport-service-groups#8
#   noticeboard-26      IMGIITRoorkee/omniport-app-noticeboard#26
#   people-search-13    IMGIITRoorkee/omniport-app-people-search#13
#   lost-and-found-7    IMGIITRoorkee/omniport-app-lost-and-found#7
#   registration-2      IMGIITRoorkee/omniport-service-registration#2
#   gif-3               IMGIITRoorkee/omniport-service-gif#3
#   pseudoc-1           IMGIITRoorkee/omniport-app-pseudoc#1
#   backend-227         IMGIITRoorkee/omniport-backend#227
#   formula-one-19      IMGIITRoorkee/omniport-backend-formula-one#19
#   backend-228         IMGIITRoorkee/omniport-backend#228
#   lectures-25         IMGIITRoorkee/omniport-app-lectures-and-tutorials#25
#   filemanager-80      IMGIITRoorkee/omniport-django-filemanager#80
#   maintainer-site-15  IMGIITRoorkee/omniport-service-maintainer-site#15
#   backend-226         IMGIITRoorkee/omniport-backend#226
#
# gym-pravesh#12 and marketplace#6 are not covered: those repositories are not
# readable with the account this was written against, so their routes and
# permissions could not be established. Guessing them would produce checks that
# look authoritative and mean nothing.
#
# Usage: ./test_pr_verification.sh https://staging.channel.iitr.ac.in
#        ./test_pr_verification.sh <url> maintainer-site-15
#        ./test_pr_verification.sh <url> list
#
# Many checks need a logged-in caller. Without a session they are reported as
# warnings, not passes:
#   SESSION_COOKIE='sessionid=<value>' ./test_pr_verification.sh <url>
#
# For the dependency check, which is not observable over HTTP:
#   DJANGO_SERVICE=intranet-server ./test_pr_verification.sh <url> backend-228

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

BASE_URL="${1:-http://localhost:8000}"
BASE_URL="${BASE_URL%/}"
SECTION="${2:-all}"
API="$BASE_URL/api"

DJANGO_SERVICE="${DJANGO_SERVICE:-intranet-server}"

PASSED=0
FAILED=0
WARNINGS=0

SECTIONS="groups-8 noticeboard-26 people-search-13 lost-and-found-7 \
registration-2 gif-3 pseudoc-1 backend-227 formula-one-19 backend-228 \
lectures-25 filemanager-80 maintainer-site-15 backend-226"

print_header() {
    echo -e "\n${BLUE}${BOLD}================================================${NC}"
    echo -e "${BLUE}${BOLD}$1${NC}"
    echo -e "${BLUE}${BOLD}================================================${NC}\n"
}

print_test() { echo -e "${BOLD}TEST:${NC} $1"; }
pass()  { echo -e "  ${GREEN}✓ PASS${NC} $1"; ((PASSED++)); }
fail()  { echo -e "  ${RED}✗ FAIL${NC} $1"; ((FAILED++)); }
warn()  { echo -e "  ${YELLOW}⚠ WARN${NC} $1"; ((WARNINGS++)); }

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

    curl -s -o /dev/null -c "$jar" --max-time 20 "$API/ensure_csrf/" 2>/dev/null
    token=$(awk '$6 == "csrftoken" {print $7}' "$jar" | tail -1)

    curl -s -o /dev/null -b "$jar" -c "$jar" --max-time 20 \
        -H "Content-Type: application/json" \
        -H "X-CSRFToken: $token" \
        -H "Referer: $BASE_URL/" \
        -d "{\"username\": \"$STAGING_USER\", \"password\": \"$STAGING_PASSWORD\"}" \
        "$API/session_auth/login/" 2>/dev/null

    session=$(awk '$6 == "sessionid" {print $7}' "$jar" | tail -1)
    rm -f "$jar"

    if [ -n "$session" ]; then
        SESSION_COOKIE="sessionid=$session"
        return 0
    fi
    return 1
}

need_session() {
    if [ -z "$SESSION_COOKIE" ]; then
        warn "$1 needs a logged-in caller; set SESSION_COOKIE to run it"
        return 1
    fi
    return 0
}

# Status code for a request carrying no credentials at all
status_of() {
    local path="$1" method="${2:-GET}" body="${3:-}"
    if [ -n "$body" ]; then
        curl -s -o /dev/null -w "%{http_code}" --max-time 20 \
            -X "$method" -H "Content-Type: application/json" \
            -d "$body" "$API$path" 2>/dev/null
    else
        curl -s -o /dev/null -w "%{http_code}" --max-time 20 \
            -X "$method" "$API$path" 2>/dev/null
    fi
}

# Status code for a request carrying the session cookie
authed_status_of() {
    local path="$1" method="${2:-GET}" body="${3:-}"
    if [ -n "$body" ]; then
        curl -s -o /dev/null -w "%{http_code}" --max-time 20 \
            -X "$method" -H "Content-Type: application/json" \
            -H "Cookie: $SESSION_COOKIE" -d "$body" "$API$path" 2>/dev/null
    else
        curl -s -o /dev/null -w "%{http_code}" --max-time 20 \
            -X "$method" -H "Cookie: $SESSION_COOKIE" "$API$path" 2>/dev/null
    fi
}

body_of() {
    curl -s --max-time 20 "$API$1" 2>/dev/null
}

# Assert an anonymous request lands on one of the expected codes.
# A 5xx is called out separately: several of these findings fail closed, and a
# 500 where a 403 belongs is a defect in its own right rather than a near miss.
expect_anonymous() {
    local path="$1" expected="$2" description="$3" method="${4:-GET}" body="${5:-}"
    local code
    code=$(status_of "$path" "$method" "$body")

    if [ "$code" = "000" ]; then
        warn "$description -> no response from $method $path"
    elif echo " $expected " | grep -q " $code "; then
        pass "$description -> HTTP $code"
    elif [ "$code" -ge 500 ] 2>/dev/null; then
        fail "$description -> HTTP $code SERVER ERROR ($method $path)"
    else
        fail "$description -> HTTP $code, expected one of [$expected] ($method $path)"
    fi
}

expect_authed() {
    local path="$1" expected="$2" description="$3" method="${4:-GET}" body="${5:-}"
    local code
    code=$(authed_status_of "$path" "$method" "$body")

    if [ "$code" = "000" ]; then
        warn "$description -> no response from $method $path"
    elif echo " $expected " | grep -q " $code "; then
        pass "$description -> HTTP $code"
    elif [ "$code" -ge 500 ] 2>/dev/null; then
        fail "$description -> HTTP $code SERVER ERROR ($method $path)"
    else
        fail "$description -> HTTP $code, expected one of [$expected] ($method $path)"
    fi
}

# Run a table of "path|expected codes|description" lines anonymously
run_anonymous_table() {
    local line path expected description
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        path="${line%%|*}"; line="${line#*|}"
        expected="${line%%|*}"; description="${line#*|}"
        expect_anonymous "$path" "$expected" "$description"
    done
}

# ---------------------------------------------------------------------------
# groups#8 - group-scoped writes are validated against the named group
# ---------------------------------------------------------------------------
section_groups_8() {
    print_header "groups#8: writes must be checked against the group in the body"

    print_test "The membership routes are closed to anonymous callers"
    run_anonymous_table <<'TABLE'
/groups/membership/|401 403|membership list
/groups/post/|401 403 200|group posts
/groups/social_link/|401 403|social links
TABLE

    print_test "A non-object JSON body must not reach the permission class"
    # has_rights_over_named_group calls request.data.get() unconditionally on a
    # non-safe method. A list or scalar body makes request.data a list or str,
    # .get raises AttributeError and DRF answers 500. It fails closed, so this
    # is a crash rather than a bypass, but it is the defect the same team is
    # fixing in the marketplace permission class.
    for payload in '[1,2]' '"a string"' '123'; do
        expect_anonymous "/groups/membership/" "400 401 403" \
            "POST body $payload" "POST" "$payload"
    done

    if need_session "the authenticated half of groups#8"; then
        print_test "The same bodies from a logged-in caller"
        for payload in '[1,2]' '"a string"' '123'; do
            expect_authed "/groups/membership/" "400 403" \
                "authenticated POST body $payload" "POST" "$payload"
        done

        print_test "A write naming a group the caller does not administer"
        expect_authed "/groups/membership/" "400 403" \
            "POST naming an unknown group" "POST" '{"group": 999999}'
        expect_authed "/groups/post/" "400 403" \
            "POST to an unknown group" "POST" '{"group": "abc"}'
    fi
}

# ---------------------------------------------------------------------------
# noticeboard#26 - no route may 500 on a caller without a person
# ---------------------------------------------------------------------------
section_noticeboard_26() {
    print_header "noticeboard#26: no notice route may return a server error"

    print_test "Every noticeboard route answers without a 500"
    run_anonymous_table <<'TABLE'
/noticeboard/new/|200 401 403|notice list
/noticeboard/old/|200 401 403|expired notices
/noticeboard/filter_list/|200 401 403|filter list
/noticeboard/filter/|200 401 403|filter
/noticeboard/date_filter_view/|200 401 403|date filter
/noticeboard/institute_notices/|200 401 403|institute notices
/noticeboard/star_filter_view/|401 403|starred notices, per-person state
/noticeboard/permissions/|200 401 403|permissions
TABLE

    print_test "star_read rejects an anonymous write rather than erroring"
    expect_anonymous "/noticeboard/star_read/" "401 403" \
        "anonymous star_read" "POST" '{"notices": [], "keyword": "read"}'

    print_test "Malformed input does not produce a server error"
    expect_anonymous "/noticeboard/new/?page=notanumber" "200 400 401 403 404" \
        "non-numeric page"
    expect_anonymous "/noticeboard/star_filter_view/?page=99999" "401 403 404" \
        "page past the end"

    echo -e "\n  ${YELLOW}Note:${NC} the case this PR is really about is an"
    echo -e "  authenticated user with no Person record, which cannot be"
    echo -e "  arranged over HTTP. Create one with manage.py createsuperuser"
    echo -e "  on staging, log in as it, and re-run with its SESSION_COOKIE."

    if need_session "the person-less caller check for noticeboard#26"; then
        print_test "The session provided does not trip a 500 anywhere"
        for path in /noticeboard/new/ /noticeboard/star_filter_view/ \
                    /noticeboard/old/ /noticeboard/filter/; do
            expect_authed "$path" "200 401 403 404" "authenticated $path"
        done
    fi
}

# ---------------------------------------------------------------------------
# people-search#13 - the write half of the router is closed
# ---------------------------------------------------------------------------
section_people_search_13() {
    print_header "people-search#13: faculty search must be read-only"

    print_test "The search routes are closed to anonymous callers"
    run_anonymous_table <<'TABLE'
/people_search/student_search/|401 403|student search
/people_search/faculty_search/|401 403|faculty search
/people_search/student_detail/|401 403|student detail
/people_search/advanced_search/|401 403|advanced search
TABLE

    print_test "An unrecognised category option must not be a server error"
    expect_anonymous "/people_search/student_search/?query=abcd&categoryOptions[]=branch" \
        "200 401 403" "unrecognised categoryOptions[]"

    if need_session "the authenticated half of people-search#13"; then
        print_test "Write methods on faculty_search are refused"
        # FacultySearch was a ModelViewSet with no http_method_names, so the
        # router mapped PUT, PATCH and DELETE onto a role table that any
        # logged-in student could reach. 405 is the fix; 200 or 204 is the bug.
        for method in POST PUT PATCH DELETE; do
            expect_authed "/people_search/faculty_search/" "405 400 403" \
                "$method on the faculty collection" "$method" '{"designation":"x"}'
        done

        print_test "Search itself still works for a logged-in caller"
        expect_authed "/people_search/student_search/" "200" "student search"
        expect_authed "/people_search/faculty_search/" "200" "faculty search"

        print_test "Another student's visibility configuration is not disclosed"
        rows=$(curl -s --max-time 20 -H "Cookie: $SESSION_COOKIE" \
               "$API/people_search/student_search/" 2>/dev/null)
        leaked=""
        for field in primaryEmailId primaryMobileNo roomNo bhawan; do
            if echo "$rows" | grep -q "\"$field\""; then
                leaked="$leaked $field"
            fi
        done
        if [ -n "$leaked" ]; then
            fail "the search list still carries the visibility arrays:$leaked"
        else
            pass "no visibility configuration in the search list"
        fi
    fi
}

# ---------------------------------------------------------------------------
# lost-and-found#7 - contact details honour the visibility flag
# ---------------------------------------------------------------------------
section_lost_and_found_7() {
    print_header "lost-and-found#7: contact details follow contact_visible"

    print_test "The dead getItem route is gone"
    expect_anonymous "/lost_and_found/lostitem/1/getItem/" "404 401 403" \
        "lostitem getItem"
    expect_anonymous "/lost_and_found/founditem/1/getItem/" "404 401 403" \
        "founditem getItem"

    print_test "No item hides an email behind a false visibility flag"
    # The old code blanked primary_phone_number and left email_address in the
    # payload, so this reads the list and looks for any row that opted out but
    # still carries contact details.
    for kind in lostitem founditem; do
        body=$(body_of "/lost_and_found/$kind/")
        if [ -z "$body" ]; then
            warn "$kind list returned nothing; cannot inspect payloads"
            continue
        fi
        if echo "$body" | grep -q "Authentication credentials"; then
            warn "$kind list needs authentication here, so payloads were not read"
            continue
        fi

        # Rows where the flag is off must carry neither an email nor a phone
        offenders=$(echo "$body" | tr '}' '\n' \
                    | grep -i '"contactVisible":[[:space:]]*false' \
                    | grep -icE '"(emailAddress|primaryPhoneNumber)":[[:space:]]*"[^"]+"')
        if [ "${offenders:-0}" -gt 0 ]; then
            fail "$kind: $offenders opted-out row(s) still carry contact details"
        else
            pass "$kind: no opted-out row carries contact details"
        fi
    done

    print_test "change_status is not an open write (known, not closed by this PR)"
    code=$(status_of "/lost_and_found/lostitem/change_status/?lostId=1")
    if [ "$code" = "200" ]; then
        warn "change_status answered 200 anonymously. Not a regression from"
        warn "this PR, but it lets any passer-by mark an item resolved."
    else
        pass "change_status -> HTTP $code"
    fi
}

# ---------------------------------------------------------------------------
# registration#2 - the registration flow stays reachable logged out
# ---------------------------------------------------------------------------
section_registration_2() {
    print_header "registration#2: the logged-out registration views stay open"

    # Note the missing trailing slashes: the urlconf declares these without
    # one, so adding it produces a 404 that reads like a broken allow-list.
    print_test "CreateSession and SetPass answer without a session"
    expect_anonymous "/registration/create_session" "200 400 405" "create_session"
    expect_anonymous "/registration/set_pass" "200 400 401 405" "set_pass" "POST" '{}'

    print_test "The staff-only registration views stay closed"
    run_anonymous_table <<'TABLE'
/registration/other_staff|401 403|other_staff
/registration/discrepancy|401 403|discrepancy
/registration/display_picture|401 403|display_picture
/registration/verify_email|401 403|verify_email
TABLE
}

# ---------------------------------------------------------------------------
# gif#3 - the roulette endpoint stays open
# ---------------------------------------------------------------------------
section_gif_3() {
    print_header "gif#3: the GIF roulette stays reachable logged out"

    print_test "Roulette answers without a session"
    expect_anonymous "/gif/roulette/" "200" "roulette"
}

# ---------------------------------------------------------------------------
# pseudoc#1 - registration open, the rest closed
# ---------------------------------------------------------------------------
section_pseudoc_1() {
    print_header "pseudoc#1: registration open, user mutation closed"

    print_test "Registration answers without a session"
    expect_anonymous "/pseudoc/registration/" "200 400 405" "registration" \
        "POST" '{}'

    print_test "create_user stays closed"
    expect_anonymous "/pseudoc/create_user/" "401 403" "create_user" "POST" '{}'

    print_test "update_user must not be anonymously writable"
    # UpdateUser declares no permission_classes. It takes a username in the
    # body and overwrites that person's contact, residence and date of birth
    # from the academic API. Anonymous today; IsAuthenticated is not enough
    # either, since any student could then rewrite anyone's records.
    code=$(status_of "/pseudoc/update_user/" "POST" '{"username":"nonexistent"}')
    case "$code" in
        401|403) pass "update_user -> HTTP $code" ;;
        400)     fail "update_user -> HTTP 400: it processed the body, so the
                      view is reachable without credentials" ;;
        *)       fail "update_user -> HTTP $code, expected 401 or 403" ;;
    esac
}

# ---------------------------------------------------------------------------
# backend#227 - the nine logged-out core views
# ---------------------------------------------------------------------------
section_backend_227() {
    print_header "backend#227: the logged-out core views stay reachable"

    print_test "Every allow-listed view answers without a session"
    run_anonymous_table <<'TABLE'
/session_auth/login/|200 400 405|session login
/session_auth/illustration_roulette/|200|illustration roulette
/bootstrap/site_branding/|200|site branding
/bootstrap/institute_branding/|200|institute branding
/bootstrap/maintainers_branding/|200|maintainers branding
/base_auth/recover_password/|200 400 405|recover password
/base_auth/verify/|200 400 405|verify recovery token
/base_auth/reset_password/|200 400 405|reset password
/base_auth/verify_secret_answer/|200 400 405|verify secret answer
TABLE

    print_test "An unknown username must not be a server error"
    # RetrieveUserSerializer.user defaults to None and validate_secret_answer
    # still runs after the username error, so self.user.failed_reset_attempts
    # raises AttributeError. That turns a 400 into a 500 and, because the view
    # declares no throttle_scope, it is not rate limited either.
    expect_anonymous "/base_auth/reset_password/" "400 405" \
        "reset_password with an unknown username" "POST" \
        '{"username":"no-such-user-here","secret_answer":"x","new_password":"y"}'
    expect_anonymous "/base_auth/verify_secret_answer/" "400 405" \
        "verify_secret_answer with an unknown username" "POST" \
        '{"username":"no-such-user-here","secret_answer":"x"}'

    print_test "Logout still requires a session"
    expect_anonymous "/session_auth/logout/" "401 403" "logout"
}

# ---------------------------------------------------------------------------
# formula-one#19 - the three bootstrap views
# ---------------------------------------------------------------------------
section_formula_one_19() {
    print_header "formula-one#19: hello, csrf and manifest stay reachable"

    print_test "All three answer without a session"
    run_anonymous_table <<'TABLE'
/hello/|200|hello
/ensure_csrf/|200|ensure_csrf
/manifest/|200|manifest
TABLE

    print_test "ensure_csrf actually sets the cookie"
    if curl -s -D - -o /dev/null --max-time 20 "$API/ensure_csrf/" 2>/dev/null \
       | grep -qi "set-cookie:.*csrftoken"; then
        pass "csrftoken cookie set"
    else
        warn "no csrftoken in the response; the login form needs this"
    fi
}

# ---------------------------------------------------------------------------
# backend#228 - the dependency bump
# ---------------------------------------------------------------------------
section_backend_228() {
    print_header "backend#228: Django and urllib3 versions"

    print_test "The installed versions are past the advisories"
    if ! command -v docker > /dev/null 2>&1; then
        warn "docker is not on this machine, so the versions cannot be read."
        warn "Run this part on the server:"
        echo -e "\n      ${BOLD}docker compose exec $DJANGO_SERVICE python -c \\"
        echo -e "        'import django, urllib3, PIL; print(django.__version__, \\"
        echo -e "         urllib3.__version__, PIL.__version__)'${NC}\n"
        return
    fi

    versions=$(docker compose exec -T "$DJANGO_SERVICE" python -c \
        'import django, urllib3, PIL; print(django.__version__, urllib3.__version__, PIL.__version__)' \
        2>/dev/null | tr -d '\r')

    if [ -z "$versions" ]; then
        warn "could not read versions from the $DJANGO_SERVICE container."
        warn "Set DJANGO_SERVICE to the right compose service name."
        return
    fi

    set -- $versions
    django_version="$1"; urllib3_version="$2"; pillow_version="$3"
    echo -e "      ${BOLD}Django${NC} $django_version  ${BOLD}urllib3${NC} $urllib3_version  ${BOLD}Pillow${NC} $pillow_version"

    case "$django_version" in
        4.1.1[3-9]*|4.1.[2-9][0-9]*|4.2.*|5.*) pass "Django $django_version" ;;
        *) fail "Django $django_version is below 4.1.13" ;;
    esac

    case "$urllib3_version" in
        1.26.2[0-9]*|1.26.[3-9][0-9]*|2.*) pass "urllib3 $urllib3_version" ;;
        *) fail "urllib3 $urllib3_version is below 1.26.20" ;;
    esac

    # Not in #228, but this is the only place the version is visible
    case "$pillow_version" in
        10.[2-9]*|10.[1-9][0-9]*|1[1-9].*|[2-9][0-9].*) pass "Pillow $pillow_version" ;;
        *) fail "Pillow $pillow_version is covered by CVE-2023-50447; the first
                 patched release is 10.2.0. See backend#229." ;;
    esac
}

# ---------------------------------------------------------------------------
# lectures#25 - the file upload view is authenticated
# ---------------------------------------------------------------------------
section_lectures_25() {
    print_header "lectures#25: file upload requires an account"

    print_test "upload_file refuses an anonymous caller"
    # Before this PR the view declared nothing and, on a falsy uploaded_file,
    # reached post.delete() with no ownership check at all.
    expect_anonymous "/lectures_and_tutorials/upload_file/" "401 403" \
        "anonymous upload" "POST" '{"post": 1, "uploaded_file": ""}'

    print_test "The deletion path is not reachable anonymously"
    expect_anonymous "/lectures_and_tutorials/upload_file/" "401 403" \
        "anonymous empty-post deletion" "POST" '{"post": 1, "uploaded_file": null}'

    print_test "A body missing its keys is a 4xx rather than a crash"
    # request.data['post'] and request.data['uploaded_file'] are bare
    # subscripts, so an absent key raises KeyError and DRF answers 500.
    expect_anonymous "/lectures_and_tutorials/upload_file/" "400 401 403" \
        "upload with no keys at all" "POST" '{}'

    print_test "The rest of the app is closed too"
    run_anonymous_table <<'TABLE'
/lectures_and_tutorials/feed/|401 403|feed
/lectures_and_tutorials/enrolled_batches/|401 403|enrolled batches
/lectures_and_tutorials/search/|401 403|global search
TABLE
}

# ---------------------------------------------------------------------------
# filemanager#80 - authentication on the file routes
# ---------------------------------------------------------------------------
section_filemanager_80() {
    print_header "filemanager#80: file access requires an account"

    print_test "The file and folder routes are closed"
    run_anonymous_table <<'TABLE'
/django_filemanager/folder/|401 403|folder list
/django_filemanager/files/|401 403|file list
/django_filemanager/filemanager/|401 403|filemanager list
/django_filemanager/all_shared_items/|401 403|shared items
/django_filemanager/all_starred_items/|401 403|starred items
TABLE

    print_test "is_admin_rights no longer answers anonymously"
    code=$(status_of "/django_filemanager/is_admin_rights/")
    case "$code" in
        401|403)
            pass "is_admin_rights -> HTTP $code"
            warn "the file manager frontend calls this outside PrivateRoute and"
            warn "only dispatches apiError on failure, so a logged-out visit to"
            warn "/admin* renders a spinner forever. Check that page by hand."
            ;;
        200) fail "is_admin_rights -> HTTP 200 without a session" ;;
        *)   fail "is_admin_rights -> HTTP $code" ;;
    esac

    print_test "Protected media is not served to an anonymous caller"
    expect_anonymous "/django_filemanager/media_files/protected/1/1/nonexistent.pdf" \
        "401 403 404" "protected media"

    if need_session "the R Drive smoke test"; then
        print_test "A logged-in caller still gets a root folder"
        # evaluate_access_permission now uses ast.literal_eval and permissions.py
        # swallows the exception as a denial, so a filemanager row holding a role
        # expression denies everyone a root folder. This is the check that tells
        # you whether the blocking concern on the PR is real on this data.
        code=$(authed_status_of "/django_filemanager/folder/get_root/")
        case "$code" in
            200) pass "get_root -> HTTP 200" ;;
            400|403) fail "get_root -> HTTP $code. If the access permission rows
                          hold role expressions rather than boolean literals,
                          every user loses their root folder. This is the R Drive
                          outage the PR is gated on." ;;
            404) warn "get_root -> HTTP 404; the route may differ on this build" ;;
            *)   fail "get_root -> HTTP $code" ;;
        esac
    fi
}

# ---------------------------------------------------------------------------
# maintainer-site#15 - public reads kept, anonymous writes closed
# ---------------------------------------------------------------------------
section_maintainer_site_15() {
    print_header "maintainer-site#15: public site readable, writes closed"

    print_test "The public pages still read without a session"
    run_anonymous_table <<'TABLE'
/maintainer_site/blog/|200|blog
/maintainer_site/social/|200|social information
/maintainer_site/location/|200|location information
/maintainer_site/contact/|200|contact information
/maintainer_site/maintainer_group/|200|maintainer group
/maintainer_site/active_maintainer_info/|200|active maintainers
/maintainer_site/projects/|200|projects
TABLE

    print_test "OPTIONS still carries the actions block"
    # SimpleMetadata.determine_actions clones the OPTIONS request as PUT/POST
    # and runs check_permissions. A permission that denies anonymous writes
    # makes DRF drop the whole actions key, and the Team, Alumni and profile
    # pages dereference options.actions.POST unconditionally in render(). This
    # is the check that catches a white-screened public site.
    for route in active_maintainer_info projects; do
        options_body=$(curl -s --max-time 20 -X OPTIONS "$API/maintainer_site/$route/" 2>/dev/null)
        if [ -z "$options_body" ]; then
            warn "OPTIONS /$route/ returned nothing"
        elif echo "$options_body" | grep -q '"actions"'; then
            pass "OPTIONS /$route/ carries actions"
        else
            fail "OPTIONS /$route/ has no actions key. The public Team and
                  Alumni pages read options.actions.POST in render() with no
                  guard, so they will white-screen for logged-out visitors."
        fi
    done

    print_test "Anonymous writes are refused"
    expect_anonymous "/maintainer_site/active_maintainer_info/" "401 403 405" \
        "POST maintainer info" "POST" '{"handle":"x"}'
    expect_anonymous "/maintainer_site/maintainer_project/" "401 403 405" \
        "POST maintainer project" "POST" '{"name":"x"}'

    print_test "The hit counter is not anonymously destructible"
    # HitViewSet.get_permissions returns a bare () for every action other than
    # list and retrieve, so DELETE is open and, because the override replaces
    # permission_classes entirely, the project-wide default never reaches it.
    expect_anonymous "/maintainer_site/hit/nonexistent-handle/" "401 403 404" \
        "anonymous DELETE of a hit row" "DELETE"
    expect_anonymous "/maintainer_site/hit/" "401 403 405" \
        "anonymous POST of a hit row" "POST" '{}'
}

# ---------------------------------------------------------------------------
# backend#226 - default deny
# ---------------------------------------------------------------------------
section_backend_226() {
    print_header "backend#226: views declaring nothing are closed by default"

    print_test "Views that declare no permissions are refused"
    # Both of these declare nothing, so they flip with the setting. The test
    # plan on the PR points at /lost_and_found/lostitem/, which declares
    # IsAuthenticatedOrReadOnly and therefore answers 200 before and after; a
    # tester following it concludes the deploy failed.
    run_anonymous_table <<'TABLE'
/lost_and_found/categories/|401 403|lost-and-found categories
/lost_and_found/recent_feed/|401 403|lost-and-found recent feed
TABLE

    print_test "The allow-listed views still answer"
    run_anonymous_table <<'TABLE'
/session_auth/login/|200 400 405|session login
/bootstrap/site_branding/|200|site branding
/hello/|200|formula-one hello
/gif/roulette/|200|gif roulette
/maintainer_site/blog/|200|maintainer site blog
TABLE

    print_test "Actions declaring an empty permission list are not skipped"
    # @action(permission_classes=[]) empties the list before initial() runs, so
    # check_permissions iterates nothing and the default never applies. These
    # return full name, enrolment number and institute webmail today.
    expect_anonymous "/student_profile/profile/00000000/handle/" "401 403 404" \
        "student profile handle action"

    print_test "Authenticated callers are unaffected"
    if need_session "the authenticated half of backend#226"; then
        expect_authed "/kernel/who_am_i/" "200" "who_am_i"
        expect_authed "/lost_and_found/categories/" "200" "categories"
    fi
}

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
        echo -e "passed. Most of them need SESSION_COOKIE. Read them before"
        echo -e "treating this as a clean result.${NC}"
    fi

    if [ $total -eq 0 ]; then
        echo -e "\n${YELLOW}${BOLD}⚠ NO CHECKS RAN${NC}"
        echo -e "${YELLOW}Every check was skipped, so nothing was verified. That is"
        echo -e "not a pass, and this exits non-zero so a pipeline cannot read it"
        echo -e "as one.${NC}\n"
        return 1
    fi

    if [ $FAILED -eq 0 ]; then
        echo -e "\n${GREEN}${BOLD}✓ ALL TESTS PASSED!${NC}\n"
        return 0
    else
        echo -e "\n${RED}${BOLD}✗ $FAILED TEST(S) FAILED${NC}\n"
        return 1
    fi
}

main() {
    echo -e "${BOLD}${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║     Channel-i Security PRs - Staging Verification              ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    if [ "$SECTION" = "list" ]; then
        echo -e "${BOLD}Sections:${NC}"
        for name in $SECTIONS; do echo "  $name"; done
        echo
        exit 0
    fi

    if [ "$SECTION" != "all" ] && ! echo " $SECTIONS " | grep -q " $SECTION "; then
        echo -e "${RED}Unknown section: $SECTION${NC}"
        echo -e "${YELLOW}Run '$0 <url> list' to see the section names${NC}\n"
        exit 1
    fi

    echo -e "${BOLD}Testing against:${NC} $BASE_URL"
    echo -e "${BOLD}Section:${NC} $SECTION"
    obtain_session || true
    if [ -n "$SESSION_COOKIE" ]; then
        echo -e "${BOLD}Session:${NC} provided"
    else
        echo -e "${BOLD}Session:${NC} ${YELLOW}not provided, authenticated checks will be skipped${NC}"
    fi
    echo

    if ! curl -s -o /dev/null --max-time 20 "$BASE_URL/" 2>/dev/null; then
        echo -e "${RED}ERROR: Cannot reach server at $BASE_URL${NC}\n"
        exit 1
    fi

    for name in $SECTIONS; do
        if [ "$SECTION" = "all" ] || [ "$SECTION" = "$name" ]; then
            "section_$(echo "$name" | tr '-' '_')"
        fi
    done

    print_summary
}

main
