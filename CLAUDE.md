# Fleet GitOps

## References

- **Fleet GitOps YAML keys** (org settings, team settings, controls, policies, queries, software, etc.):
  https://fleetdm.com/docs/configuration/yaml-files

  Consult these when adding, renaming, or validating any key before guessing at structure.

- **Apple configuration profile payload keys** (`.mobileconfig` payloads under `fleets/*/macos-settings/`):
  https://developer.apple.com/documentation/devicemanagement/profile-specific-payload-keys

  Consult this whenever authoring or editing a configuration profile — verify the payload type, keys, value types, and supported OS versions before writing or changing any payload.

- **Apple Declarative Device Management (DDM)** declarations:
  https://developer.apple.com/documentation/devicemanagement/declarations

  Consult this whenever authoring or editing a DDM declaration — verify the declaration type, payload schema, and required/optional fields before writing or changing any declaration.

