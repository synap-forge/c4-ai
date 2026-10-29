package com.structurizr.dsl;

import java.io.File;
import java.lang.reflect.Constructor;
import java.util.List;

import com.structurizr.documentation.Documentable;
import com.structurizr.documentation.Section;
import com.structurizr.importer.documentation.DefaultImageImporter;
import com.structurizr.importer.documentation.DocumentationImporter;

final class DocsParser extends AbstractParser {

    private static final String DEFAULT_DOCUMENT_IMPORTER = "com.structurizr.importer.documentation.DefaultDocumentationImporter";

    private static final String GRAMMAR = "!docs <path> <fqn>";

    private static final int PATH_INDEX = 1;
    private static final int FQN_INDEX = 2;

    void parse(WorkspaceDslContext context, File dslFile, Tokens tokens) {
        parse(context, context.getWorkspace(), dslFile, tokens);
    }

    void parse(SoftwareSystemDslContext context, File dslFile, Tokens tokens) {
        parse(context, context.getSoftwareSystem(), dslFile, tokens);
    }

    void parse(ContainerDslContext context, File dslFile, Tokens tokens) {
        parse(context, context.getContainer(), dslFile, tokens);
    }

    void parse(ComponentDslContext context, File dslFile, Tokens tokens) {
        parse(context, context.getComponent(), dslFile, tokens);
    }

    void parseExclude(DocsDslContext context, Tokens tokens) {
        if (!tokens.includes(PATH_INDEX)) {
            throw new RuntimeException("Expected: exclude <regex> [regex...]");
        }

        for (int i = PATH_INDEX; i < tokens.size(); i++) {
            String regex = tokens.get(i);
            if (regex.length() >= 2 && regex.startsWith("\"") && regex.endsWith("\"")) {
                regex = regex.substring(1, regex.length() - 1);
            }
            context.addExclude(regex);
        }
    }

    private void parse(DslContext context, Documentable documentable, File dslFile, Tokens tokens) {
        // !docs <path>

        context.setDslPortable(false);

        if (tokens.hasMoreThan(FQN_INDEX)) {
            throw new RuntimeException("Too many tokens, expected: " + GRAMMAR);
        }

        if (!tokens.includes(PATH_INDEX)) {
            throw new RuntimeException("Expected: " + GRAMMAR);
        }

        String fullyQualifiedClassName = DEFAULT_DOCUMENT_IMPORTER;
        if (tokens.includes(FQN_INDEX) && !"{".equals(tokens.get(FQN_INDEX))) {
            fullyQualifiedClassName = tokens.get(FQN_INDEX);
        }

        importDocumentation(context, documentable, dslFile, tokens.get(PATH_INDEX), fullyQualifiedClassName, List.of());
    }

    void importDocumentation(DslContext context, Documentable documentable, File dslFile, String pathToken, String fullyQualifiedClassName, List<String> excludes) {
        if (dslFile != null) {
            File path = new File(dslFile.getParentFile(), pathToken);

            if (!path.exists()) {
                throw new RuntimeException("Documentation path " + path + " does not exist");
            }

            try {
                Class<?> documentationImporterClass = context.loadClass(fullyQualifiedClassName, dslFile);
                Constructor<?> constructor = documentationImporterClass.getDeclaredConstructor();
                DocumentationImporter documentationImporter = (DocumentationImporter)constructor.newInstance();
                documentationImporter.importDocumentation(documentable, path);

                if (!excludes.isEmpty()) {
                    documentable.getDocumentation().getSections().stream()
                            .filter(section -> isExcluded(section, excludes))
                            .forEach(documentable.getDocumentation()::removeSection);
                }

                if (DEFAULT_DOCUMENT_IMPORTER.equals(fullyQualifiedClassName) && path.isDirectory()) {
                    DefaultImageImporter imageImporter = new DefaultImageImporter();
                    imageImporter.importDocumentation(documentable, path);
                }
            } catch (ClassNotFoundException cnfe) {
                throw new RuntimeException("Error importing documentation from " + path.getAbsolutePath() + ": " + fullyQualifiedClassName + " was not found");
            } catch (Exception e) {
                throw new RuntimeException("Error importing documentation from " + path.getAbsolutePath() + ": " + e.getMessage());
            }
        }
    }

    private boolean isExcluded(Section section, List<String> excludes) {
        String filename = section.getFilename();
        if (filename == null) {
            return false;
        }

        for (String regex : excludes) {
            if (filename.matches(regex) || new File(filename).getName().matches(regex)) {
                return true;
            }
        }

        return false;
    }

}