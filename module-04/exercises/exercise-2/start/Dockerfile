# syntax=docker/dockerfile:1
# Exercise 4.2: this build leaks the rulebook token. Fix it; the check runs:
#   docker build -f module-04/exercises/exercise-2/Dockerfile --build-context scripts=module-04/04-build-secrets \
#     --secret id=rulebook_token,src=.lab/m04x2/rulebook-token.txt -t brightlane/pricing:m04x2 .lab/m04x2
FROM brightlane/pricing:0.5
COPY rulebook-token.txt /tmp/rulebook-token
RUN --mount=type=bind,from=scripts,source=fetch_rulebook.py,target=/tmp/fetch_rulebook.py \
    python /tmp/fetch_rulebook.py /tmp/rulebook-token
RUN rm /tmp/rulebook-token
