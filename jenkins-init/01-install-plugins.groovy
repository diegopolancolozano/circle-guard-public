// Install required plugins automatically
import jenkins.model.Jenkins
import hudson.model.UpdateSite

def jenkins = Jenkins.getInstance()
def pluginManager = jenkins.getPluginManager()
def updateCenter = jenkins.getUpdateCenter()

// List of required plugins
def requiredPlugins = [
    'workflow-multibranch',           // Multibranch Pipeline
    'workflow-job',                   // Workflow API
    'pipeline-model-definition',      // Declarative Pipeline
    'pipeline-stage-view',            // Stage View Plugin
    'git',                            // Git plugin
    'github-branch-source',           // GitHub Branch Source
    'docker-plugin',                  // Docker plugin
    'docker-pipeline',                // Docker Pipeline
    'kubernetes',                     // Kubernetes plugin
    'kubernetes-cli',                 // Kubernetes CLI
    'credentials',                    // Credentials plugin
    'credentials-binding',            // Credentials Binding
    'ssh-credentials',                // SSH Credentials
    'timestamper',                    // Log Parser / Timestamper
    'log-parser'                      // Log Parser Plugin
]

println("Starting plugin installation...")

// Check and install plugins
requiredPlugins.each { pluginName ->
    def plugin = pluginManager.getPlugin(pluginName)
    if (plugin == null) {
        println("Installing plugin: $pluginName")
        def pluginObject = updateCenter.getPlugin(pluginName)
        if (pluginObject != null) {
            pluginObject.deploy()
        } else {
            println("Warning: Could not find plugin $pluginName in update center")
        }
    } else {
        println("Plugin already installed: $pluginName (version ${plugin.getVersion()})")
    }
}

// Wait for plugin downloads to complete
while (updateCenter.isUpdating()) {
    Thread.sleep(1000)
}

println("Plugin installation process completed!")
jenkins.save()
