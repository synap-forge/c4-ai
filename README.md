# Structurizr

This repo represents the consolidated version of all Structurizr tooling.

- [Introducing Structurizr vNext](https://www.patreon.com/posts/146923136)
- [Building from source](https://docs.structurizr.com/building)
- [Binaries](https://docs.structurizr.com/binaries)
- [Commands](https://docs.structurizr.com/commands)

## Building from source

[Guide to building Structurizr from source](https://docs.structurizr.com/building)
```bash
./mvnw -DexcludedGroups=IntegrationTest package
```

&& 

```bash
./mvnw -Dmaven.test.skip=true package
```


java -jar -Dserver.port=9090 -Dstructurizr.themes=/Users/anasiri2/Developments/appsrc/open-sources/structurizr/structurizr-themes/ structurizr-application/target/structurizr-1.0.0.war playground


java -jar structurizr-application/target/structurizr-1.0.0.war push -url http://localhost:8080/api -id 2 -workspace /Users/anasiri2/Developments/appsrc/lululemon/retail-services-architecture-resources/Discount/ai.dsl


java -jar -Dstructurizr.themes=/Users/anasiri2/Developments/appsrc/open-sources/structurizr/structurizr-themes/ structurizr-application/target/structurizr-1.0.0.war server 


java -jar structurizr-application/target/structurizr-1.0.0.war local 

 java -jar structurizr-application/target/structurizr-1.0.0.war server --enable-native-access=ALL-UNNAMED


 java -jar structurizr-application/target/structurizr-1.0.0.war branches 


java -jar -Dstructurizr.themes=/Users/anasiri2/Developments/appsrc/open-sources/structurizr/structurizr-themes/ structurizr-application/target/structurizr-1.0.0.war push -url http://localhost:8080/api -id 3 -workspace /Users/anasiri2/Developments/appsrc/lululemon/retail-services-architecture-resources/giftcard-webhook/workspace.dsl


java -jar structurizr-application/target/structurizr-1.0.0.war export \
  -w workspace.dsl \
  -f plantuml \
  -o ./diagrams


java -jar structurizr-application/target/structurizr-1.0.0.war export \
  -w workspace.dsl \
  -f static \
  -o ./diagrams


Available formats:

Flag	Output
plantuml	PlantUML (Structurizr dialect)
plantuml/c4plantuml	C4-PlantUML
mermaid	Mermaid diagrams
websequencediagrams	WebSequenceDiagrams
json	Workspace JSON
theme	Theme JSON
static	Static HTML site

