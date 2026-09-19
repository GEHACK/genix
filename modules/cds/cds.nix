{
  config,
  contest_id,
  ...
}:
{

  config = {
    sops.secrets = {
      "cds.ccs.password" = { };
      "cds.admin.password" = { };
      "cds.presadmin.password" = { };
      "cds.presentation-client.password" = { };
      "cds.analyst.password" = { };
    };

    sops.templates."cds.env".content = ''
      ADMIN_PASSWORD=${config.sops.placeholder."cds.admin.password"}
      PRESADMIN_PASSWORD=${config.sops.placeholder."cds.presadmin.password"}
      PRESENTATION_PASSWORD=${config.sops.placeholder."cds.presentation-client.password"}
      LIVE_PASSWORD=${config.sops.placeholder."cds.analyst.password"}
    '';
    sops.templates."cdsConfig.xml".content = ''
      <cds>
        <contest location="/contest" recordReactions="true">
          <ccs url="https://judge.gehack.nl/api/contests/${contest_id}" user="cds" password="${config.sops.placeholder."cds.ccs.password"}"/>
          <video desktop="http://{0}.team.loom:8080/screencast.ts"
                 desktopMode="eager"
                 webcam="http://{0}.team.loom:8080/webcam.ts"
                 webcamMode="eager"/>
        </contest>
      </cds>
    '';
    sops.templates."server.xml".content = ''
      <server description="ICPC contest data server">
        <javaVirtualMachine>
          <jvmOptions>
            <jvmOption>-Xms12288m</jvmOption>
            <jvmOption>-Xmx12288m</jvmOption>
          </jvmOptions>
        </javaVirtualMachine>

        <featureManager>
          <feature>pages-3.1</feature>
          <feature>jndi-1.0</feature>
          <feature>websocket-2.1</feature>
          <feature>appSecurity-5.0</feature>
          <feature>servlet-6.0</feature>
          <feature>cdi-4.0</feature>
        </featureManager>

        <!-- If you have root access, change port numbers to httpPort="80" httpsPort="443" -->
        <httpEndpoint host="*" httpPort="8080" httpsPort="8443" id="defaultHttpEndpoint">
          <tcpOptions soReuseAddr="true"/>
          <httpOptions ThrowIOEForInboundConnections="true"/>
        </httpEndpoint>

        <httpSession invalidationTimeout="8h" idReuse="true"/>

        <keyStore id="defaultKeyStore" password="{xor}FhwPHAswMDMs" />
        <!--<ssl id="defaultSSLConfig" keyStoreRef="defaultKeyStore" trustDefaultCerts="true" />-->

        <jndiEntry jndiName="icpc.cds.config" value="/opt/wlp/usr/servers/cds/config"/>

        <webApplication id="CDS" location="CDS.war" name="CDS" contextRoot="/"/>
      </server>
    '';

    virtualisation.oci-containers = {
      backend = "docker";
      containers.cds = {
        image = "ghcr.io/icpctools/cds:2.7.1401";
        autoStart = true;
        ports = [ "8443:8443" ];
        volumes = [
          "/var/lib/cds:/contest"
          "${config.sops.templates."cdsConfig.xml".path}:/opt/wlp/usr/servers/cds/config/cdsConfig.xml"
          "${config.sops.templates."server.xml".path}:/opt/wlp/usr/servers/cds/server.xml"
        ];
        environmentFiles = [ config.sops.templates."cds.env".path ];
      };
    };

    networking.firewall.allowedTCPPorts = [ 8443 ];
  };
}
