# KVAS 1.1.9_beta-10-353

This is a local compatibility release based on the published
1.1.9_beta-10-352 package, with narrowly scoped safety fixes for the
VLESS/Proxy21 path. It is not installed on a router by this work.

## Changes

- Keep the beta-10-352 application tree and its RULE_PRIORITY=99 baseline.
- Require all three Keenetic interface indicators before KVAS enables VPN
  marking: state=up, link=up, and connected=yes.
- Stop if KVAS cannot create the routing table or its auxiliary route; do not
  continue by installing marking rules over an unready table.
- Do not synthesize the hard-coded /24 helper route for VLESS Proxy21,
  whose transport interface is a /32 proxy interface.
- Use the installed router's S97xray service name consistently for VLESS.
- Keep /opt/etc/ndm/ndm and the runtime libs/ndm source identical so the
  post-install copy cannot silently restore different behavior.
- Increment the package release to 353.

## Deliberate non-changes

- No router configuration, route, iptables rule, DNS configuration, or VPN
  selection was changed.
- No automatic update or deployment mechanism is included.
- This release does not claim that a VLESS switch is safe until it is tested
  on the router with an independently verified rollback path.

## Main risks

The package replaces the KVAS application tree when installed. It must first
be tested against a router backup and the local S97xray/DNS bridge setup.
The route-table guard intentionally refuses to enable marking when the
selected interface is not fully connected; this can leave KVAS on the prior
working VPN rather than attempting a partial switch.
