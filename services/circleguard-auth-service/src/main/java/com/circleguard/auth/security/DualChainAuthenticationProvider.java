package com.circleguard.auth.security;

import com.circleguard.auth.service.CustomUserDetailsService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.*;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.core.*;
import org.springframework.security.ldap.authentication.LdapAuthenticationProvider;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class DualChainAuthenticationProvider implements AuthenticationProvider {

    @Autowired(required = false)
    private LdapAuthenticationProvider ldapProvider;

    private final DaoAuthenticationProvider localProvider;

    @Override
    public Authentication authenticate(Authentication authentication) throws AuthenticationException {
        // If LDAP provider present, try it first
        if (ldapProvider != null) {
            try {
                return ldapProvider.authenticate(authentication);
            } catch (AuthenticationException e) {
                // fall through to local provider
            }
        }
        // Fallback to Local DB
        return localProvider.authenticate(authentication);
    }

    @Override
    public boolean supports(Class<?> authentication) {
        return UsernamePasswordAuthenticationToken.class.isAssignableFrom(authentication);
    }
}
