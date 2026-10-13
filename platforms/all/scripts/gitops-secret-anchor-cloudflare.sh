#!/bin/bash
# No-op. Never run on a host.
#
# This file exists only so GitOps uploads $FLEET_SECRET_CF_CLIENT_SECRET to Fleet.
# GitOps collects FLEET_SECRET_* values from scripts and profiles, but not from an
# Android app's managed configuration JSON, which is where this secret is used:
# platforms/android/managed-app-configurations/cloudflare-one-agent-testing.json
#
# Remove this file once Fleet GitOps scans Android app configurations for secrets.
exit 0
