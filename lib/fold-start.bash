if [[ -n "${TRAVIS:-}" ]]; then
  echo -e "travis_fold:start:$0\033[33;1m$0\033[0m"
fi
