# Exercise 4.2: No token left behind

`start/Dockerfile` adds Brightlane's tariff rulebook to the pricing image, fetched with a token
during the build, and leaks the token. Fix it: the build must still fetch the rulebook, and the
token must be nowhere in the image, its history or its configuration.

The check runs the build exactly like this, with a fresh token and the rulebook server running:

```bash
docker build -f module-04/exercises/exercise-2/Dockerfile \
  --build-context scripts=module-04/04-build-secrets \
  --secret id=rulebook_token,src=.lab/m04x2/rulebook-token.txt \
  -t brightlane/pricing:m04x2 .lab/m04x2
```

1. Copy `start/Dockerfile` into this folder (`module-04/exercises/exercise-2/`) and fix it.
2. Check: `python -m pytest module-04/exercises/exercise-2`
