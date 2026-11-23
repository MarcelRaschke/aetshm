#!/usr/bin/env bash
#
# Setzt die GitHub-Actions-Secrets und -Variablen für den SonarQube-Workflow
# (.github/workflows/sonarqube.yml).
#
# Voraussetzungen: gh (angemeldet, Admin-Rechte auf dem Repo), curl.
#
# Aufruf (SonarCloud, Standardwerte):
#   ./scripts/setup-sonar.sh
#
# Aufruf mit abweichenden Werten:
#   SONAR_ORGANIZATION=meine-org SONAR_PROJECT_KEY=meine-org_aetshm ./scripts/setup-sonar.sh
#
# Eigene SonarQube-Instanz (ohne Organization):
#   SONAR_HOST_URL=https://sonar.example.ch SONAR_ORGANIZATION= ./scripts/setup-sonar.sh
#
# Der Token wird verdeckt eingelesen (nicht in History oder Prozessliste) und
# vor dem Speichern gegen den Server validiert.

set -euo pipefail

REPO="${REPO:-MarcelRaschke/aetshm}"
HOST="${SONAR_HOST_URL:-https://sonarcloud.io}"
KEY="${SONAR_PROJECT_KEY:-MarcelRaschke_aetshm}"
ORG="${SONAR_ORGANIZATION-marcelraschke}"
REF="${REF:-main}"

for bin in gh curl; do
  command -v "$bin" >/dev/null || { echo "Fehlt: $bin" >&2; exit 1; }
done
gh auth status >/dev/null 2>&1 || { echo "gh ist nicht angemeldet (gh auth login)" >&2; exit 1; }

echo "Repo:         $REPO"
echo "Host:         $HOST"
echo "Project Key:  $KEY"
echo "Organization: ${ORG:-<keine>}"
echo

read -rsp "SONAR_TOKEN: " TOKEN; echo
[[ -n "$TOKEN" ]] || { echo "Token leer – Abbruch" >&2; exit 1; }

if ! curl -fsS -u "$TOKEN:" "$HOST/api/authentication/validate" | grep -q '"valid":true'; then
  echo "Token ist für $HOST ungültig – Abbruch" >&2
  exit 1
fi
echo "Token gültig."

printf '%s' "$TOKEN" | gh secret set SONAR_TOKEN    -R "$REPO"
printf '%s' "$TOKEN" | gh secret set SONAR_TOKEN    -R "$REPO" --app dependabot
printf '%s' "$HOST"  | gh secret set SONAR_HOST_URL -R "$REPO"
unset TOKEN

gh variable set SONAR_PROJECT_KEY -R "$REPO" --body "$KEY"
if [[ -n "$ORG" ]]; then
  gh variable set SONAR_ORGANIZATION -R "$REPO" --body "$ORG"
else
  gh variable delete SONAR_ORGANIZATION -R "$REPO" 2>/dev/null || true
fi

echo
gh secret list -R "$REPO"
gh variable list -R "$REPO"

gh workflow run "SonarQube analysis" -R "$REPO" --ref "$REF"
echo
echo "Scan gestartet: https://github.com/$REPO/actions/workflows/sonarqube.yml"
