package com.structurizr.dsl;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

import com.structurizr.documentation.Documentable;

class DocsDslContext extends DslContext {

    private final File dslFile;
    private final Documentable documentable;
    private final String path;
    private final String fullyQualifiedClassName;
    private final List<String> excludes = new ArrayList<>();

    DocsDslContext(File dslFile, Documentable documentable, String path, String fullyQualifiedClassName) {
        this.dslFile = dslFile;
        this.documentable = documentable;
        this.path = path;
        this.fullyQualifiedClassName = fullyQualifiedClassName;
    }

    void addExclude(String regex) {
        excludes.add(regex);
    }

    @Override
    void end() {
        new DocsParser().importDocumentation(this, documentable, dslFile, path, fullyQualifiedClassName, excludes);
    }

    @Override
    protected String[] getPermittedTokens() {
        return new String[] { StructurizrDslTokens.EXCLUDE_IN_VIEW_TOKEN };
    }
}