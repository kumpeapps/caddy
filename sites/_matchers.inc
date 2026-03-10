# Common Matchers
# Import these with: import /sites/_matchers.caddy

# =============================================================================
# HTTP METHOD MATCHERS
# =============================================================================
# Match safe HTTP methods
@safe_methods {
    method GET HEAD OPTIONS
}

# Match state-changing methods
@unsafe_methods {
    method POST PUT PATCH DELETE
}

# =============================================================================
# CONTENT TYPE MATCHERS
# =============================================================================
# Match API requests
@api_request {
    header Content-Type *application/json*
    header Accept *application/json*
}

# Match form submissions
@form_submit {
    header Content-Type *application/x-www-form-urlencoded*
    header Content-Type *multipart/form-data*
}

# =============================================================================
# CLIENT TYPE MATCHERS
# =============================================================================
# Match mobile devices
@mobile {
    header User-Agent *Mobile*
    header User-Agent *Android*
    header User-Agent *iPhone*
    header User-Agent *iPad*
    header User-Agent *Windows Phone*
}

# Match desktop browsers
@desktop {
    not header User-Agent *Mobile*
    not header User-Agent *Android*
    not header User-Agent *iPhone*
    not header User-Agent *iPad*
}

# =============================================================================
# PATH MATCHERS
# =============================================================================
# Match admin paths
@admin {
    path /admin /admin/*
    path /dashboard /dashboard/*
    path /wp-admin /wp-admin/*
}

# Match API paths
@api {
    path /api /api/*
    path /v1 /v1/*
    path /v2 /v2/*
}

# Match static assets
@static_assets {
    path *.css *.js *.jpg *.jpeg *.png *.gif *.ico *.svg
    path *.woff *.woff2 *.ttf *.eot *.otf
    path *.webp *.avif *.bmp *.tiff
    path *.map *.json *.xml
}

# Match images
@images {
    path *.jpg *.jpeg *.png *.gif *.webp *.avif *.svg *.ico *.bmp *.tiff
}

# Match media files
@media {
    path *.mp4 *.webm *.ogg *.mp3 *.wav *.flac *.aac *.m4a
    path *.avi *.mov *.wmv *.flv
}

# Match documents
@documents {
    path *.pdf *.doc *.docx *.xls *.xlsx *.ppt *.pptx
    path *.txt *.csv *.zip *.tar *.gz
}

# =============================================================================
# SECURITY MATCHERS
# =============================================================================
# Match requests without referer (potential bots/scripts)
@no_referer {
    not header Referer *
    not method GET HEAD
}

# Match requests without user agent
@no_user_agent {
    not header User-Agent *
}

# Match localhost/internal requests
@local {
    remote_ip 127.0.0.1/8
    remote_ip ::1
    remote_ip 10.0.0.0/8
    remote_ip 172.16.0.0/12
    remote_ip 192.168.0.0/16
}

# Match external requests
@external {
    not remote_ip 127.0.0.1/8
    not remote_ip ::1
    not remote_ip 10.0.0.0/8
    not remote_ip 172.16.0.0/12
    not remote_ip 192.168.0.0/16
}

# =============================================================================
# GOOD BOTS
# =============================================================================
@search_engines {
    header User-Agent *Googlebot*
    header User-Agent *bingbot*
    header User-Agent *DuckDuckBot*
    header User-Agent *Yahoo! Slurp*
}

@social_media_bots {
    header User-Agent *facebookexternalhit*
    header User-Agent *LinkedInBot*
    header User-Agent *TwitterBot*
    header User-Agent *TelegramBot*
    header User-Agent *Slackbot*
    header User-Agent *WhatsApp*
}

@monitoring_bots {
    header User-Agent *Pingdom*
    header User-Agent *UptimeRobot*
    header User-Agent *StatusCake*
    header User-Agent *Datadog*
}
