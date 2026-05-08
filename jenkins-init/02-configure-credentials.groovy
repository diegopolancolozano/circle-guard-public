// Jenkins credentials auto-configuration
// Este script se ejecutará al iniciar Jenkins para configurar credenciales básicas

import jenkins.model.Jenkins
import com.cloudbees.plugins.credentials.CredentialsProvider
import com.cloudbees.plugins.credentials.domains.Domain
import com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl
import org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl
import hudson.util.Secret

def jenkins = Jenkins.getInstance()
def credentialsStore = jenkins.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()
def domain = Domain.global()

println("Configurando credenciales de Jenkins...")

// Función auxiliar para crear credenciales con ID único
def createCredential(id, description, credential) {
    try {
        // Verificar si la credencial ya existe
        def existing = credentialsStore.getCredentials(domain).find { it.id == id }
        if (existing) {
            println("  ⚠ Credencial ya existe: $id")
            return
        }
        
        // Crear nueva credencial
        credentialsStore.addCredentials(domain, credential)
        println("  ✓ Credencial creada: $id")
    } catch (Exception e) {
        println("  ✗ Error creando credencial $id: ${e.message}")
    }
}

// 1. Placeholder para Docker Hub credentials (se configura manualmente)
println("  ℹ Docker Hub credentials: se deben configurar manualmente en Jenkins UI")
println("    - ID: dockerhub-credentials")
println("    - Tipo: Username with password")

// 2. Placeholder para Kubeconfig (se configura manualmente)
println("  ℹ Kubeconfig credentials: se deben configurar manualmente en Jenkins UI")
println("    - ID: kubeconfig-credentials")
println("    - Tipo: Secret file")

// 3. Placeholder para GCP SA JSON (se configura manualmente)
println("  ℹ GCP Service Account: se debe configurar manualmente en Jenkins UI")
println("    - ID: gcp-sa-json")
println("    - Tipo: Secret file")

// 4. Crear credential de ejemplo para QR_SECRET (cambiar según sea necesario)
try {
    def qrSecretId = "qr-secret-value"
    def existing = credentialsStore.getCredentials(domain).find { it.id == qrSecretId }
    if (!existing) {
        def qrSecret = new StringCredentialsImpl(
            CredentialsScope.GLOBAL,
            qrSecretId,
            "QR Secret for JWT/QR token generation",
            Secret.fromString("change-me-change-me-change-me-change-me")
        )
        credentialsStore.addCredentials(domain, qrSecret)
        println("  ✓ Credencial QR_SECRET creada (debe cambiar valor en Jenkins UI)")
    }
} catch (Exception e) {
    println("  ℹ Credencial QR_SECRET (error: ${e.message})")
}

// 4b. Crear placeholder para GCP SA JSON para evitar fallas en pipelines locales
try {
    def gcpId = "gcp-sa-json"
    def existingGcp = credentialsStore.getCredentials(domain).find { it.id == gcpId }
    if (!existingGcp) {
        def gcpCred = new StringCredentialsImpl(
            CredentialsScope.GLOBAL,
            gcpId,
            "GCP Service Account JSON (placeholder for local runs)",
            Secret.fromString("{}")
        )
        credentialsStore.addCredentials(domain, gcpCred)
        println("  ✓ Credencial placeholder gcp-sa-json creada (cambiar en Jenkins UI si necesita acceso a GCP)")
    } else {
        println("  ℹ Credencial gcp-sa-json ya existe")
    }
} catch (Exception e) {
    println("  ✗ Error creando credencial gcp-sa-json: ${e.message}")
}

jenkins.save()
println("Configuración de credenciales completada!")
println("")
println("⚠  PRÓXIMOS PASOS MANUALES EN JENKINS UI:")
println("  1. Manage Jenkins → Credentials → System → Global credentials")
println("  2. Agregar credenciales faltantes:")
println("     - dockerhub-credentials (Username + Token)")
println("     - kubeconfig-credentials (Secret file: ~/.kube/config)")
println("     - gcp-sa-json (Secret file: GCP Service Account JSON)")
println("  3. Cambiar valor de qr-secret-value si es necesario")
