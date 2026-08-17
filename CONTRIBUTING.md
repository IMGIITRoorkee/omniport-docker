# Contributing to Omniport

Conventions for changes to any Omniport repository.
They are drawn from what the codebase already does, and from `omniport-backend#222`, which spent four of its commits doing nothing but bringing comments and docstrings back into line.

The theme running through all of it: **the code says what, the commit message says why.** Most of the rules below are that one rule applied somewhere.

## Pull request description

Five headings, in this order, and nothing else at the top level.

```markdown
## Summary

## Issue

## Steps to reproduce the bug/issue

## Steps done to fix it and test added for the same

## Criteria for issue to be resolved
```

`.github/pull_request_template.md` fills these in on every new pull request.
A free-form description, however well written, should be rewritten into this shape.

**Summary.** What the pull request changes, in a few sentences.

**Issue.** What is wrong today.
Link the issue or finding.
Describe the defect, not the fix, and give the file and line.

**Steps to reproduce.** Numbered steps someone else can follow on an unpatched checkout, with the request and the observed response where it is reachable over HTTP.
Where it is not reproducible at runtime, say so and give the code that demonstrates it instead.

**Steps done to fix it.** What changed and why that closes the issue.
Name the test file and the workflow that runs it.

**Criteria for issue to be resolved.** Conditions a reviewer can check off, one per line, written so someone who has not read the diff can still tell whether they hold.
The CI run is one of them.

### Tests have to run in CI

A test described only in the description, or run once by hand in a scratch directory, does not count.
Commit it, and wire it into the repository's workflow so it runs on every push and pull request.

**Observe every new test failing before you believe it.** A guard you have only seen pass is not yet known to be a guard.
The way to establish that is to break the thing it guards and watch it fail:

```
delete all six scope_to_visible_notices calls             green -> FAILED
append a viewset with permission_classes = [AllowAny, ]   green -> FAILED
```

That table belongs in the description.
It is the difference between a test that asserts something and a test that happens to pass.

## Commits

### Subject

Imperative mood, sentence case, no trailing period, no prefix or scope tag, no ticket number.
Say what the change does in the language of the domain.

```
Move password recovery constants to a constants module
Let Django own the security response headers
Drop the redundant Host header check on password recovery
Keep serving password recovery over GET while it is deprecated
Register the security middleware higher in the stack
Stop marking the CSRF cookie HttpOnly
```

Not `fix: password recovery (#123)`, not `SECURITY: rate limiting`, not `Updated views.py`.

### Body

Flowing prose in paragraphs, wrapped at about 72 characters.
**No bullet lists.**
Explain what was wrong, what the change does about it, and any trade-off taken deliberately.
This is where the reasoning lives, so it can afford to be long where the change earns it.

A body worth copying, from `dcc00d0`:

> `SecurityHeadersMiddleware` set five headers that `SecurityMiddleware` and
> `XFrameOptionsMiddleware`, both already in `MIDDLEWARE`, emit from settings,
> and that NGINX adds again on every response. Since `add_header` appends
> rather than replaces, clients received `X-Frame-Options` twice with
> conflicting values, which browsers resolve inconsistently and some answer by
> ignoring the header altogether.
>
> Delete the class and declare the headers as settings instead. Keep
> `SAMEORIGIN`, which is what NGINX has been configured to send, rather than
> the stricter `DENY` the middleware chose.
>
> The remaining duplicate is NGINX, whose `add_header` lines for these four
> headers belong in a change to `omniport-docker`.

Three things that body does, all worth imitating:

- **Names the mechanism**, not just the symptom: *`add_header` appends rather
  than replaces*.
- **States a decision that could have gone the other way**, and why:
  `SAMEORIGIN` over `DENY`.
- **Says what it deliberately leaves undone**, and where that belongs.

If a change fixes a test that was wrong, say why it was wrong.
From `4164fc0`:

> The test that guarded this asserted the scrub, against `/api/kernel/`, which
> is not where the kernel is mounted, and without credentials against a view
> that requires them, so it was reading a 404 body.

### One change per commit

`#222` split into twenty commits, each doing one thing.
A commit that moves constants moves constants; a commit that trims comments trims comments.
That is what makes the body able to explain a single decision.

## Comments

### One line

Cut every comment to a single line.
If the reasoning needs a paragraph, it belongs in the commit message.

```python
# Before
# Rate limits, as the number of requests allowed per window of that many
# seconds, kept separate per scope so that either can be tuned or, in tests,
# tightened or relaxed on its own

# After
# Rate limits, as requests allowed per window of that many seconds
```

### Explain the why, never narrate the what

The code already says what it does.
A comment earns its line by carrying something a reader cannot infer: a constraint, a trade-off, a reason.

```python
# Before
# ALWAYS return identical response - CRITICAL for preventing enumeration

# After
# The same response either way, so that accounts cannot be enumerated
```

No capitals for emphasis, no `CRITICAL`, no `IMPORTANT`, no dashes used as exclamation marks.
If it matters, say why it matters, plainly.

### Match what the neighbours do

Before adding a comment, look at the declarations around it.
If peer entries carry none, yours makes your line stick out rather than makes it clearer.

`ff40f42` deleted a correct, useful comment for exactly this reason:

> The list carries no comments, its groupings separated by blank lines alone.
> The ordering this one explained is in the commit that made it.

### Never write

- Tool or agent attribution of any kind, in any form
- Pull request numbers, issue numbers or ticket IDs, which rot the moment the
  code moves. State the constraint itself; git already tracks the history
- CWE identifiers, severity ratings, or mitigation lists in a docstring
- Commented-out code

## Docstrings

### Modules

```python
"""
This file defines the security options for Omniport
"""
```

### Classes

One sentence saying what it is.
Where behaviour matters to a caller, say it in the same sentence rather than in a list under it.

```python
# Before
"""
Password recovery endpoint.

SECURITY FIXES (CWE-640, CWE-799, CWE-204):
- POST-only (prevents GET enumeration)
- Rate-limited (3/IP/hour, 1/account/hour)
- Identical response for valid/invalid (prevents username enumeration)
- CSRF-protected
- Host header validation
"""

# After
"""
POST only password recovery endpoint, rate limited per IP and per account,
which responds identically whether or not the account exists
"""
```

Note what else went: the figures `3/IP/hour, 1/account/hour` were restated from the constants module, where they cannot go stale.
**A docstring should not duplicate a value that lives in code.**

### Methods

The house form for a view method, followed by a blank line before the body:

```python
def get(self, request, *args, **kwargs):
    """
    View to serve GET requests
    :param request: the request that is to be responded to
    :param args: arguments
    :param kwargs: keyword arguments
    :return: the response for request
    """

    ...
```

For a plain function, one line saying what it is, and `:param:` / `:return:` where the signature is not self-evident:

```python
def rate_limit_check(key, limit=IP_RATE_LIMIT, window=IP_RATE_LIMIT_WINDOW):
    """
    Fixed window counter, allowing `limit` hits on `key` per `window` seconds
    """
```

## Constants

Declared together in a constants module, not beside their single use.
A constant defined next to the one line that reads it is invisible to whoever has to change it next.

Group by concern, one blank line between groups, one single-line comment per group rather than per constant:

```python
# Rate limits, as requests allowed per window of that many seconds
IP_RATE_LIMIT = 3
IP_RATE_LIMIT_WINDOW = 3600
ACCOUNT_RATE_LIMIT = 1
ACCOUNT_RATE_LIMIT_WINDOW = 3600

# Prefixes of the cache keys holding the rate limit counters
IP_RATE_LIMIT_KEY_PREFIX = 'password_reset:ip'
ACCOUNT_RATE_LIMIT_KEY_PREFIX = 'password_reset:account'

# The shortest username that is worth looking up
MINIMUM_USERNAME_LENGTH = 2
```

Every app keeps its own constants package; the project keeps one too.

## Code

Write the least code that works.
Reuse an existing helper, type or pattern before adding one, and prefer the standard library or an installed dependency over a new abstraction.
No interface with one implementation, no factory for one product, no configuration for a value that never changes.

When a block needs more than two lines of comment to explain itself, that is the signal to extract it into a named function.
The name carries the explanation and the call site keeps its two lines.

Fix a pattern everywhere in the same pass.
When a review points at one instance of something, grep for it and fix every occurrence, including the copy in the template and the docs.
A fix applied only to the line that was pointed at guarantees a second round.

Prefer a mechanical check to an instruction wherever the property is mechanically checkable.
A rule in this document is missed by exactly the people who know it; a lint rule, a gitignore entry or a CI step is not.

## Prose

No em dashes.
Use a plain dash.

In Markdown files, put each full sentence on its own line.
It keeps diffs readable when a paragraph is edited.
