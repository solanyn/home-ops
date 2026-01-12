applications = {
  audiobookshelf = { group = "user", icon = "audiobookshelf", redirect_uris = ["/auth/openid/callback"] }
  autobrr        = { group = "user", icon = "autobrr", redirect_uris = ["/api/auth/oidc/callback"] }
  bazarr         = { group = "user", icon = "bazarr", redirect_uris = ["/oauth2/callback"] }
  booklore       = { group = "user", icon = "booklore", redirect_uris = ["/oauth2-callback"], public = true }
  ersatztv       = { group = "user", icon = "ersatztv", redirect_uris = ["/oidc/callback"] }
  flux           = { group = "admin", icon = "flux-cd", redirect_uris = ["/oauth2/callback"] }
  gitlab         = { group = "admin", icon = "gitlab", redirect_uris = ["/users/auth/openid_connect/callback"] }
  grafana        = { group = "admin", icon = "grafana", redirect_uris = ["/login/generic_oauth"] }
  headlamp       = { group = "admin", icon = "headlamp", redirect_uris = ["/oidc-callback"] }
  immich         = { group = "user", icon = "immich", redirect_uris = ["/auth/login", "/user-settings", "app.immich:/"] }
  kubeflow       = { group = "admin", icon = "kubeflow", redirect_uris = ["/dex/callback"] }
  librechat      = { group = "user", icon = "librechat", redirect_uris = ["/oauth/openid/callback"] }
  lidarr         = { group = "user", icon = "lidarr", redirect_uris = ["/oauth2/callback"] }
  mealie         = { group = "user", icon = "mealie", redirect_uris = ["/login"] }
  prowlarr       = { group = "user", icon = "prowlarr", redirect_uris = ["/oauth2/callback"] }
  qui            = { group = "user", icon = "qui", redirect_uris = ["/api/auth/oidc/callback"] }
  radarr         = { group = "user", icon = "radarr", redirect_uris = ["/oauth2/callback"] }
  romm           = { group = "user", icon = "romm", redirect_uris = ["/api/oauth/openid"] }
  sftpgo         = { group = "user", icon = "sftpgo", redirect_uris = ["/web/oidc/callback"] }
  sonarr         = { group = "user", icon = "sonarr", redirect_uris = ["/oauth2/callback"] }
  stash          = { group = "user", icon = "stash", redirect_uris = ["/oauth2/callback"] }
  trino          = { group = "admin", icon = "trino", redirect_uris = ["/oauth2/callback"] }
  whisparr       = { group = "user", icon = "whisparr", redirect_uris = ["/oauth2/callback"] }
}
