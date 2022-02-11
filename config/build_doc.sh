#!/bin/bash
java -jar ~/Downloads/widoco-1.4.15-jar-with-dependencies.jar \
     -confFile ./build_doc.properties \
     -includeImportedOntologies \
     -rewriteAll \
     -ontFile ./solis/abv_schema.ttl \
     -lang nl \
     -webVowl
     -rewriteBase /_doc