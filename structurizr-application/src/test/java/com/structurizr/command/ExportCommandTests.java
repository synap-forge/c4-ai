package com.structurizr.command;

import org.junit.jupiter.api.Test;

import java.io.File;
import java.nio.file.Files;

import static org.junit.jupiter.api.Assertions.assertTrue;

public class ExportCommandTests {

    @Test
    public void run() throws Exception {
        File tmpDir = Files.createTempDirectory("structurizr").toFile();

        File workspaceFile = new File(tmpDir, "workspace.dsl");
        Files.writeString(workspaceFile.toPath(), """
                workspace {
                    model {
                        softwareSystem "Software System"
                    }
                    views {
                        systemLandscape "SystemLandscape" {
                            include *
                            autoLayout
                        }
                    }
                }
                """);

        String[] args = {
                "export",
                "-workspace", workspaceFile.getAbsolutePath(),
                "-output", tmpDir.getCanonicalPath(),
                "-format", "plantuml"
        };
        assertTrue(new ExportCommand().run(args));

        assertTrue(new File(tmpDir, "structurizr-SystemLandscape.puml").exists());
    }

    @Test
    @org.junit.jupiter.api.Tag("IntegrationTest")
    void exportsPngAndSvg(@org.junit.jupiter.api.io.TempDir java.nio.file.Path directory) throws Exception {
        com.structurizr.Workspace workspace = new com.structurizr.Workspace("Export test", "");
        var system = workspace.getModel().addSoftwareSystem("Example system");
        var person = workspace.getModel().addPerson("Reader");
        person.uses(system, "Uses");
        var view = workspace.getViews().createSystemLandscapeView("Landscape", "");
        view.addAllElements();
        view.enableAutomaticLayout();
        File input = directory.resolve("workspace with spaces.json").toFile();
        com.structurizr.util.WorkspaceUtils.saveWorkspaceToJson(workspace, input);
        for (String format : new String[] { "png", "svg" }) {
            assertTrue(new ExportCommand().run("-w", input.getAbsolutePath(), "-f", format,
                    "-o", directory.toString()));
            File output = directory.resolve("Landscape." + format).toFile();
            assertTrue(output.length() > 100);
            if (format.equals("png")) {
                var image = javax.imageio.ImageIO.read(output);
                assertTrue(image.getWidth() > 0 && image.getHeight() > 0);
            } else {
                assertTrue(Files.readString(output.toPath()).contains("<svg"));
            }
        }
    }

}