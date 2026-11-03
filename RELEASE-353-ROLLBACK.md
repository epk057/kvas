# Manual rollback plan for KVAS 353

This is a reviewed manual procedure for a future router deployment. It is not
executed by the build or test scripts.

## Before deployment

1. Keep the current working OpenVPN selected as the fallback.
2. Save the router's current KVAS, Xray, DNS bridge, hook, and rescue files in
   a new timestamped backup outside the package staging directory.
3. Copy the known-good beta-10-352 IPK to the router and verify its checksum.
4. Confirm that console or an independent LAN access path is available. Do
   not rely on the VLESS path for recovery.
5. Record the current WAN interface/default route and confirm direct internet
   access before installing anything.

## If the new package fails

Do not switch VPNs repeatedly. From a local console or independent SSH path:

opkg install /opt/tmp/kvas_1.1.9_beta-10-352_all.ipk

Then restore the locally customized S97xray references and any files saved
in the pre-deployment backup, restart only the affected KVAS/Xray service, and
verify direct WAN access, DNS, and the existing OpenVPN. If the route table is
missing and the saved WAN gateway/interface still match the live connection,
use the existing local rescue procedure rather than inventing a new route.

## Stop conditions

Stop and use the independent recovery path if the main default route changes,
the gateway becomes unreachable, LAN DNS fails, or SSH/web access is lost.
Do not flush all routes or iptables rules. Do not delete Proxy21 as a first
response.

The exact package diff can be reviewed with:

git diff dce04b4..HEAD -- Makefile opt tests RELEASE-353-CHANGELOG.md RELEASE-353-ROLLBACK.md
