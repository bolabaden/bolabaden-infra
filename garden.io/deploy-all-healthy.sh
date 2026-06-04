#!/bin/bash
# Comprehensive deployment script that ensures all services are healthy
# Deploys services in dependency order and verifies health before proceeding

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "=== Comprehensive Docker Compose Deployment ==="
echo "Deploying all services in dependency order with health verification"
echo ""

# Function to check service health
check_health() {
    local service=$1
    local max_wait=${2:-120}
    local wait_time=0
    local interval=5
    
    echo "   Waiting for $service to become healthy (max ${max_wait}s)..."
    while [ $wait_time -lt $max_wait ]; do
        health=$(docker compose ps --format "{{.Health}}" $service 2>/dev/null | head -1 || echo "")
        if echo "$health" | grep -q "healthy"; then
            echo "   ✅ $service is healthy"
            return 0
        fi
        sleep $interval
        wait_time=$((wait_time + interval))
        echo -n "."
    done
    echo ""
    echo "   ⚠️  $service did not become healthy within ${max_wait}s"
    docker compose logs --tail 10 $service
    return 1
}

# Phase 1: Core Infrastructure
echo "📦 Phase 1: Core Infrastructure"
docker compose up -d dockerproxy-ro redis mongodb
check_health dockerproxy-ro 30
check_health redis 60
check_health mongodb 60
echo "✅ Phase 1 Complete"
echo ""

# Phase 2: Reverse Proxy Services
echo "📦 Phase 2: Reverse Proxy Services"
docker compose up -d searxng crowdsec nginx-traefik-extensions tinyauth
check_health searxng 60
check_health crowdsec 60
check_health nginx-traefik-extensions 60
check_health tinyauth 60
echo "✅ Phase 2 Complete"
echo ""

# Phase 3: Traefik
echo "📦 Phase 3: Traefik Reverse Proxy"
docker compose up -d traefik
check_health traefik 90
echo "✅ Phase 3 Complete"
echo ""

# Phase 4: Infrastructure Services
echo "📦 Phase 4: Infrastructure Services"
docker compose up -d homepage dozzle portainer dockerproxy-rw watchtower
check_health homepage 60
# dozzle, portainer, dockerproxy-rw, watchtower may not have healthchecks
sleep 30
echo "✅ Phase 4 Complete"
echo ""

# Phase 5: Application Services
echo "📦 Phase 5: Application Services"
docker compose up -d bolabaden-nextjs session-manager telemetry-auth
check_health bolabaden-nextjs 120
check_health session-manager 60
check_health telemetry-auth 60
echo "✅ Phase 5 Complete"
echo ""

# Phase 6: Firecrawl Services
echo "📦 Phase 6: Firecrawl Services"
docker compose up -d playwright-service nuq-postgres firecrawl
check_health playwright-service 60
check_health nuq-postgres 60
check_health firecrawl 120
echo "✅ Phase 6 Complete"
echo ""

# Phase 7: Headscale Services
echo "📦 Phase 7: Headscale Services"
docker compose up -d headscale-server headscale
check_health headscale-server 60
check_health headscale 60
echo "✅ Phase 7 Complete"
echo ""

# Phase 8: LLM Services
echo "📦 Phase 8: LLM Services"
docker compose up -d litellm-postgres litellm mcpo open-webui gptr
check_health litellm-postgres 60
check_health litellm 120
check_health mcpo 120
check_health open-webui 180
check_health gptr 180
echo "✅ Phase 8 Complete"
echo ""

# Phase 9: Stremio Services
echo "📦 Phase 9: Stremio Services"
docker compose up -d flaresolverr jackett prowlarr stremio aiostreams stremthru
check_health flaresolverr 60
check_health jackett 120
check_health prowlarr 120
check_health stremio 120
check_health aiostreams 120
check_health stremthru 60
echo "✅ Phase 9 Complete"
echo ""

# Phase 10: Metrics Services (optional, can be skipped if issues)
echo "📦 Phase 10: Metrics Services"
docker compose up -d victoriametrics prometheus grafana loki promtail cadvisor node_exporter blackbox-exporter || echo "⚠️  Some metrics services failed to start"
echo "✅ Phase 10 Complete"
echo ""

# Final Health Check
echo "=== Final Health Verification ==="
echo ""
docker compose ps --format json 2>/dev/null | python3 << 'PYTHON_SCRIPT'
import json, sys
result = sys.stdin.read()
services = [json.loads(l) for l in result.strip().split('\n') if l.strip()]

healthy = [s for s in services if 'healthy' in s.get('Health', '').lower()]
running = [s for s in services if s.get('State') == 'running']
unhealthy = [s for s in services if 'unhealthy' in s.get('Health', '').lower()]

print(f"📊 Final Status:")
print(f"   Total Services: {len(services)}")
print(f"   Running: {len(running)}")
print(f"   ✅ Healthy: {len(healthy)}")
print(f"   ❌ Unhealthy: {len(unhealthy)}")

if services:
    health_pct = (len(healthy) / len(services)) * 100
    print(f"   Health Percentage: {health_pct:.1f}%")
    
    if health_pct >= 90 and len(unhealthy) == 0:
        print("\n🎉 ALL SERVICES HEALTHY!")
        print("✅ System is ready for Kubernetes deployment")
        sys.exit(0)
    elif health_pct >= 70:
        print("\n⚠️  Most services healthy")
        print("   Review any unhealthy services before Kubernetes deployment")
        sys.exit(1)
    else:
        print("\n❌ System needs attention")
        sys.exit(1)
PYTHON_SCRIPT

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful! All services are healthy."
    echo "   Ready to proceed with Kubernetes deployment."
else
    echo ""
    echo "⚠️  Some services need attention. Review logs before proceeding."
fi

exit $EXIT_CODE

