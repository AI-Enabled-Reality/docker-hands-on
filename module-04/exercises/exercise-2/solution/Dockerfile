# syntax=docker/dockerfile:1
# Exercise 4.2, a solution: the token as a build secret, mounted as a file for one RUN.
#   docker build -f module-04/exercises/exercise-2/solution/Dockerfile --build-context scripts=module-04/04-build-secrets \
#     --secret id=rulebook_token,src=.lab/m04x2/rulebook-token.txt -t brightlane/pricing:m04x2 .lab/m04x2
FROM brightlane/pricing:0.5
RUN --mount=type=bind,from=scripts,source=fetch_rulebook.py,target=/tmp/fetch_rulebook.py \
    --mount=type=secret,id=rulebook_token \
    python /tmp/fetch_rulebook.py /run/secrets/rulebook_token
