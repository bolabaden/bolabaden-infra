# Wishlist Setup - Complete Integration

## Service Overview
The Wishlist application has been fully implemented and deployed to your bolabaden infrastructure.

**Project Repository:** https://github.com/cmintey/wishlist  
**Docker Image:** ghcr.io/cmintey/wishlist:latest  
**Container Name:** wishlist  
**Port:** 3280 (internal) → accessible via Traefik on wishlist.bolabaden.org

## Architecture

### Compose Configuration
- **Location:** [compose/docker-compose.wishlist.yml](compose/docker-compose.wishlist.yml)
- **Integration:** Added to main [docker-compose.yml](docker-compose.yml) includes list
- **Networks:** Connected to both `publicnet` and `backend` for internal/external communication

### Service Configuration

#### Container Details
- **Image:** `ghcr.io/cmintey/wishlist:latest`
- **Hostname:** wishlist
- **Restart Policy:** Always
- **Health Check:** Enabled with 30s interval

#### Volumes
- **Uploads:** `${CONFIG_PATH:-./volumes}/wishlist/uploads:/usr/src/app/uploads`
- **Data:** `${CONFIG_PATH:-./volumes}/wishlist/data:/usr/src/app/data`

#### Environment Variables
```
ORIGIN=https://wishlist.${DOMAIN}                    # User-facing URL
TOKEN_TIME=72                                        # Token expiration (hours)
DEFAULT_CURRENCY=USD                                 # Default currency for pricing
LOG_LEVEL=info                                       # Logging level
MAX_IMAGE_SIZE=5000000                               # Max image upload size (5MB)
```

#### Traefik Routing
- **Rule:** `Host('wishlist.bolabaden.org')`
- **Port:** 3280
- **TLS:** Enabled
- **Health Check:** Enabled on root path with 30s interval

#### Homepage Integration
- **Group:** Media
- **Icon:** giftopen.png
- **Health Status:** Monitored with Kuma uptime tracker

## Features

The Wishlist application provides:
- **Multiple groups** for friends and family
- **Wish item management** - add items to your list
- **Claim system** - others can claim items to purchase
- **Public registry mode** - share wishlists without authentication
- **Suggestions** - add items to others' wishlists (with approval options)
- **SMTP support** - email invitations and password resets
- **OAuth/OpenID Connect** - external authentication support
- **Translation** - multi-language support via Weblate

## Configuration Guide

### Setting ORIGIN URL
The `ORIGIN` environment variable is critical and defaults to `https://wishlist.${DOMAIN}`.

If running behind a proxy or with a different domain:
```yaml
environment:
  ORIGIN: "https://your-custom-domain.com"
```

### Nginx/Reverse Proxy Configuration
If running behind Nginx or Synology NAS, configure these buffer settings:
```nginx
proxy_buffer_size 128k;
proxy_buffers 4 256k;
proxy_busy_buffers_size 256k;
```

### Public Signup
- **Default:** Enabled - anyone with URL can sign up
- **Admin Panel:** Can disable and require invitations only
- **With SMTP:** Invite links can be emailed
- **Without SMTP:** Invite links are manually generated

### Group Management
- **Group Creators:** Automatically become managers
- **Managers:** Can invite users, add/remove group members, delete groups
- **Admin Level:** Has same permissions as managers across all groups

## First Time Setup

1. **Access the application:** http://localhost:3280 or https://wishlist.bolabaden.org
2. **Create an account:** Initial account creation requires no signup restrictions
3. **Configure via Admin Panel:**
   - Enable/disable public signup
   - Configure SMTP if desired
   - Set up OAuth/OIDC if needed
   - Configure suggestion behavior
4. **Create/join groups:** Set up friend/family groups for wish sharing

## File Structure

```
/home/ubuntu/my-media-stack/
├── docker-compose.yml                         # Main compose file (updated with wishlist include)
├── compose/
│   └── docker-compose.wishlist.yml           # Wishlist-specific configuration
└── volumes/wishlist/
    ├── uploads/                               # User-uploaded images
    └── data/                                  # Application database
```

## Management Commands

### Container Management
```bash
# View wishlist container status
docker ps | grep wishlist
docker inspect wishlist

# View logs
docker logs wishlist -f

# Restart service
docker restart wishlist

# Stop service
docker stop wishlist

# Start service
docker start wishlist
```

### Database/Data Management
```bash
# Access SQLite database
docker exec -it wishlist sh

# Backup wishlist data
cp -r ./volumes/wishlist ./volumes/wishlist.backup.$(date +%s)

# View wishlist volumes
du -sh ./volumes/wishlist/
```

## Monitoring

### Health Status
- **Docker Health Check:** Running every 30 seconds
- **Traefik Health Check:** Monitoring root path `/`
- **Kuma Uptime Monitoring:** Integrated into kuma.wishlist.http

### Container Logs
Monitor for any startup or runtime issues:
```bash
docker logs wishlist --tail=100
```

## Next Steps

1. **Access the web interface:** Visit https://wishlist.bolabaden.org
2. **Configure authentication:**
   - Enable SMTP for email invitations (optional)
   - Set up OAuth/OIDC if using external auth (optional)
   - Configure admin email for notifications
3. **Customize groups:**
   - Create family/friend groups
   - Invite users via link or email
   - Set suggestion and registry modes as needed
4. **Integrate with Homepage:** Already configured to show on homepage dashboard

## Troubleshooting

### Container won't start
```bash
docker logs wishlist
# Check for environment variable errors or port conflicts
```

### Can't access web interface
- Verify Traefik routing: https://traefik.bolabaden.org
- Check DNS resolution for wishlist.bolabaden.org
- Verify TLS certificate is valid
- Check if origin URL is correct in environment

### Database locked errors
- Single SQLite database - ensure only one instance is running
- Check volume permissions: `ls -la ./volumes/wishlist/data/`

### Image upload issues
- Verify MAX_IMAGE_SIZE setting (default 5MB)
- Check disk space: `df -h ./volumes/wishlist/uploads/`
- Ensure upload directory has correct permissions

## References

- **GitHub Repository:** https://github.com/cmintey/wishlist
- **Docker Image:** ghcr.io/cmintey/wishlist
- **Documentation:** See README.md in official repository
- **Community Helm Chart:** https://github.com/mddeff/wishlist-charts
- **Weblate Translations:** https://hosted.weblate.org/projects/wishlist/

## Integration Status

✅ **Docker Compose:** Configured and added to main docker-compose.yml  
✅ **Networks:** Connected to publicnet and backend  
✅ **Traefik:** HTTP routing configured with TLS  
✅ **Health Checks:** Enabled with automatic restart  
✅ **Homepage Dashboard:** Integrated with widget and health status  
✅ **Kuma Monitoring:** Included in uptime tracking  
✅ **Volumes:** Persistent storage for uploads and data  
✅ **Container:** Running and accessible on port 3280

## Service Status

**Current Status:** ✅ RUNNING  
**Container ID:** d2d5550824d5e31bdbdb1e8cc41b747f170218f3bcb9c178a52fac5229d4de00  
**Image:** ghcr.io/cmintey/wishlist:latest  
**Uptime:** ~1 minute (newly started)  
**Port Binding:** 0.0.0.0:3280→3280/tcp
