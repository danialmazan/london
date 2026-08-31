# Building-height source decision

The EMU Analytics map and the proposed London layer share the same broad method: open building outlines combined with aerial LiDAR, with Environment Agency LiDAR used in England. They are not automatically the same distributable dataset.

As checked on 30 August 2026, EMU's former data-pack page redirects to its current corporate site and no London sample or redistribution terms can be verified there. The Atlas therefore does **not** copy, scrape, or re-publish the EMU layer.

The production route is an open derivation from Environment Agency first-return DSM and DTM elevation, constrained to an explicitly open building-footprint source such as OS OpenMap Local. That high-volume raster build must record the vintage of every LiDAR tile, the height statistic used for each footprint, coverage gaps, and the licence of every input. Until that work passes coverage and spot-check validation, the public manifest omits the height layer and building-height-status.json records why. Missing coverage must remain No data.
