# Add non-personal parcel attributes (land value, lot size, land use) to the corridor parcels -----
# Source: Maine GeoLibrary "Maine Parcels Organized Towns", ownership/attribute table (Camden rows only).
# PRIVACY: this script never requests owner names, mailing addresses or sale prices. The one exception
# is a yes/no test for a few named parcels (see check_public below): the owner field is fetched, tested
# against a pattern in memory, and only TRUE/FALSE is kept.
# Run from the project root:  Rscript gis/04_parcel_attributes.R
# Output: gis/data/parcel_attributes.csv   (parcel ID, land value, lot size and units, land use)

suppressPackageStartupMessages({ library(sf); library(jsonlite) })
svc <- "https://services1.arcgis.com/RbMX0mRVOFNTdLzd/arcgis/rest/services/Maine_Parcels_Organized_Towns/FeatureServer/9/query"
parcels <- st_read("gis/data/parcels_corridor.gpkg", quiet = TRUE)
geocodes <- unique(parcels$GEOCODE)                      # corridor parcels span a few towns
camden_code <- unique(parcels$GEOCODE[toupper(parcels$TOWN) == "CAMDEN"]); stopifnot(length(camden_code) == 1)

fetch_rows <- function(where, fields) {
  out <- list(); offset <- 0
  repeat {
    q <- paste0(svc, "?where=", utils::URLencode(where, reserved = TRUE), "&outFields=", fields,
                "&returnGeometry=false&resultOffset=", offset, "&resultRecordCount=2000&f=json")
    r <- fromJSON(q)
    if (!is.null(r$error)) stop("Service error: ", r$error$message)
    if (!length(r$features)) break
    out[[length(out) + 1]] <- r$features$attributes
    if (!isTRUE(r$exceededTransferLimit)) break
    offset <- offset + 2000
  }
  do.call(rbind, out)
}

attrs <- fetch_rows(sprintf("GEOCODE IN (%s)", paste0("'", geocodes, "'", collapse = ",")),
                    "GEOCODE,MAP_BK_LOT,LAND_VAL,LOT_SIZE,LOT_UNITS,LAND_USE,LAND_USE_D")
key <- function(g, m) paste(g, m)
attrs <- attrs[key(attrs$GEOCODE, attrs$MAP_BK_LOT) %in% key(parcels$GEOCODE, parcels$MAP_BK_LOT), ]
attrs <- attrs[!duplicated(key(attrs$GEOCODE, attrs$MAP_BK_LOT)), ]
dir.create("gis/data", showWarnings = FALSE)
write.csv(attrs, "gis/data/parcel_attributes.csv", row.names = FALSE)
message("Saved ", nrow(attrs), " corridor parcels with attributes (no owner fields).")

# Yes/no check of public ownership for named parcels (nothing but TRUE/FALSE is kept) ---------------
check_public <- function(ids) {
  where <- sprintf("GEOCODE='%s' AND MAP_BK_LOT IN (%s)", camden_code, paste0("'", ids, "'", collapse = ","))
  r <- fetch_rows(where, "MAP_BK_LOT,OWNER1")
  data.frame(MAP_BK_LOT = r$MAP_BK_LOT,
             owner_looks_public = grepl("TOWN OF|CITY OF|STATE OF|COUNTY|UNITED STATES|, TOWN|CAMDEN TOWN|SCHOOL|MSAD|RSU",
                                        toupper(r$OWNER1)))
}
if (file.exists("gis/private/check_ids.txt")) {
  ids <- readLines("gis/private/check_ids.txt")
  print(check_public(ids), row.names = FALSE)
}
