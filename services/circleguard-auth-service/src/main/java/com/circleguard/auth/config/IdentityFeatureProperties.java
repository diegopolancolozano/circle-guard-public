package com.circleguard.auth.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "features.identity")
public class IdentityFeatureProperties {
    private boolean useRemote = true;

    public boolean isUseRemote() {
        return useRemote;
    }

    public void setUseRemote(boolean useRemote) {
        this.useRemote = useRemote;
    }
}
