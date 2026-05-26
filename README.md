G3-Checks

Getting started
Convert https://gde.kapschtraffic.com/global-services/icinga2/icinga2-g3-hlm2-checks to regular Bash using Curl:
Advantages:

No need for developer maintenance of pip python environment
No need for the Libraries that are likely to cause compatibility and security issues

List of G3 MLFF Services that run by defualt in any G3 implementation:

OMAD Backup
Mlff Tools Log Collection
Rss Log Collection
RavenDB Tools
ETCS Data Interface Service
Configuration Service
Collect and Evaluate Service
REMS (Always implemented customized, based on project implementation: Csa Norway REMS)
AutoPASS (Always implemented customized, based on project implementation: Csa Norway AutoPASS)


List of G3 RSS Srvices that run by default attached to a Traffic Station Controller:

- ALC
- PFM
- VDC
- VR
- TSMC


List of Segments status pulled from the TOMO API:

- tollingDomain
- tollingPoint
- tollingSegment


Check_g3_mlff script checks individual services based on service name. Check_g3_mlff is used to monitor the G3 MLFF Services@

Example:  ./check_g3_mlff -s "OMAD Backup"


Check_g3_rss script checks Roadside Traffic Station Controller services:

Example:  ./check_g3_rss -do 45 -tp 3 -ts 1 -in 1 -de VDC


Check_g3_segment script pulls the Segment status:

 Example:  ./check_g3_segment -do 45 -tp 3 -ts 1