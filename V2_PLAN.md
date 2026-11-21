# V2 plan: from a model about worlds to a case that decision-makers can use

Written 2026-11-07 after feedback from Geoffrey Scott. V1 (everything in `GAME_PLAN.md`) stays as
the research layer. V2 adds what V1 lacked: real costs, real parcels, a plain comparison with the
options the Town actually funds, and a check of what the law says about injuries.

## 1. What Geoffrey said, and what V2 does about it

| What Geoffrey said | What V2 does about it |
|---|---|
| Decision-makers will not follow the modeling. They want it to happen and need a clear, simple way to justify it. They need it really summarized. | A one-page decision brief in the Town budget's own terms (Town dollars per unit of benefit). The stakeholder worlds stay as separate models behind it and are shown side by side, not merged into one score. |
| It competes for Town money with sidewalks and with wider shoulders. | Those become the comparison options. Doing nothing is the baseline. |
| Next to the road it is far too expensive, mostly drainage (ditches, culverts) and grading. It should be scratched in. | A cost model with a drainage and grading term. "Scratched in" means a narrow trail cut into existing ground with little earthmoving. |
| It should be on land of owners who agree. Property maps matter. | A willing-owner chain model on real parcels: the route is a sequence of parcels, each owner agrees or not, and the shoulder fills each gap. |
| Truth-ground it with Strava, Trailforks and the Camden GIS maps. | See section 3. |

## 2. Options in V2 (all compete for the same Town money)

| Option | What it is | Main cost driver |
|---|---|---|
| A. Scratched-in trail | Narrow trail on willing owners' land, shoulder where an owner declines | Number of agreeing parcels, drainage and grading on steep or wet ground |
| B. Wider shoulders | Widen Hosmer Pond Road and connecting streets | Length, drainage, land at road edges |
| C. Sidewalks | Sidewalks on the streets the Town would otherwise build them | Length, curbing, drainage |
| D. Do nothing | Reference | None |

## 3. Truth grounding: sources and status (2026-11-07)

| Source | What it gives | Status |
|---|---|---|
| Maine GeoLibrary parcels (state service) | Parcel boundaries for the corridor (about 1,600 parcels) | Done. `gis/data/parcels_corridor.gpkg`. No owner names or addresses saved. |
| Same service, attribute table | Assessed land value, lot size (looks like acres, units field is empty), land use | Done 2026-11-07. `gis/data/parcel_attributes.csv`. Assessed values are not market prices and can be lowered by Maine current-use tax programs. |
| Camden town GIS hub | Plow routes, drainage, waterbodies; no parcel layer | Read. The tax maps page returned 403 to us (US-only access). |
| Town assessor, 8 Washington Street | Authoritative current ownership and parcel maps | Cory to ask; also to confirm which parcels on Geoffrey's route are Town-owned. |
| Strava | Where recreational riders record activities | Not reachable by us (login, and permission limited to OpenStreetMap tracing). Cory may look himself. Evidence about corridor choice, not demand. |
| Trailforks | Mapped trails and use on the trail network | Not checked yet. |
| USGS elevation | Grades along candidate routes | Done in the earlier GIS step. |
| Public Works (drainage and road costs) | What ditches, culverts and grading cost on Camden roads | Geoffrey's lead; ask Public Works. |
| Town budget and capital improvement plan | What sidewalks and shoulders cost the Town | Not read yet. |

Privacy rule: the repository is public. Owner names, owner addresses, and any parcel-level list of
where a proposed trail would cross are never committed. Parcel-level route work lives in
`gis/private/`, which is ignored by git, until owners have been approached. Geoffrey's map and notes
(`26_GeoffreyScott_*`) are also ignored, because they carry owner names and an email address.

## 4. What the law says about injuries (read 2026-11-07, statutes only, not court cases)

| Provision (Title 14 of the Maine statutes) | What it says | What it means for the Town |
|---|---|---|
| Section 8104-A, road construction and repair | The government is liable for negligent acts "arising out of and occurring during the performance of construction, street cleaning or repair operations" on public ways, and is "not liable for any defect, lack of repair or lack of sufficient railing" | Liability attaches to negligent work, not to the absence of a shoulder or path |
| Section 8104-B, discretionary functions | Immune when "performing or failing to perform a discretionary function or duty, whether or not the discretion is abused" | A decision not to build is a judgment call and very likely immune |
| Section 8105, limits | At most $400,000 per occurrence; no punitive damages | Even a successful claim is capped |

So a cyclist struck on a road without a shoulder is most likely a claim against the driver, not
the Town. This is a reading of the statute text, not legal advice and not a review of court
decisions. Camden's actual claims history is unknown; Town records or its insurer would show it.
Consequence for V2: injuries avoided are not a Town financial saving beyond emergency response.
They are reported as counts (a community harm), not converted to dollars.

## 5. Sidewalks: what could be found (2026-11-07)

| Item | What was found | Source |
|---|---|---|
| Simonton Corner | Appears to be in Rockport, not Camden (2012 Rockport records) | Rockport listening tour |
| John Street and Route 1 sidewalk | A MaineDOT project: sidewalk and shoulders on John Street from Simonton Road to Route 1; construction reported as late 2025 to fall 2026 | Camden StoryMap, title only; search summary |
| Elm Street and Route 1 sidewalk | "Over $1 million to construct"; MaineDOT "won't fund as is" and wants the Town to commit to fixing the intersection | Pathways Committee minutes, January 4, 2023 |
| Mountain Street | Only a 2016 list item for lower Central Street to the Route 1 and Mountain Street intersection, priority 0 | Pathways Committee minutes, 2016 |

No current Town proposal "around Simonton Corner and Mountain Street" was found. If MaineDOT pays
for the John Street sidewalk, it does not compete for Town money. Cory or Geoffrey should say where
the Simonton Corner and Mountain Street idea comes from (a Select Board agenda item, for example).

## 6. Model changes

1. Replace the single path cost per kilometer with a base cost by construction type (scratched-in,
   roadside graded, shoulder, sidewalk) plus a drainage and grading term driven by the share of the
   route on steep, wet or ledge ground. Ranges stay placeholders until Public Works or a quote
   supplies numbers. One anchor exists: an Elm Street sidewalk estimated above $1 million.
2. Add the willing-owner chain on the real parcels: an agreement probability per parcel, the
   shoulder as fallback for each refusal, and the Select Board vote as a separate decision for
   Town-owned parcels. Key outputs: expected share of the route that is trail, and the agreement
   probability needed for the trail to beat the shoulder (a switching value).
3. Compare options by Town dollars per trip served, and report injuries avoided as counts.
4. Keep the V1 stakeholder models as separate worlds; do not convert them into the Town's currency.

## 7. Worked example for the willing-owner chain

Geoffrey's drawn route crosses about eight parcels. By his labels, four have named private owners,
one is Town land (the state data agrees), and up to three are marked "Town?", which the state data
does not confirm. Take the four private parcels. Suppose each owner agrees with probability 0.7 and
owners decide independently. Both numbers are invented. The chance all four agree is 0.7 to the
fourth power: 0.7 squared is 0.49, and 0.49 squared is 0.2401, so about 24%. With 0.9 per owner,
0.9 squared is 0.81 and 0.81 squared is 0.6561, so about 66%. The expected share of private parcels
that say yes is 70% or 90%. The Town parcels need a Select Board vote, not an owner's consent.

## 8. Decisions needed from Cory

1. Ask the assessor which parcels on Geoffrey's route are Town-owned.
2. Strava: skip it, ask Strava Metro for permission, or look yourself and tell us what you see.
3. Where does the Simonton Corner and Mountain Street sidewalk idea come from?
4. Is this repository folder (`camden_carriage_road`) now the only live copy of the project?
