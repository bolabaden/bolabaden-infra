import robotsParser, { Robot } from "robots-parser";
import axios from "axios";
import { axiosTimeout } from "./timeout";
import https from "https";
import { Logger } from "winston";

function isIPv4Address(hostname: string): boolean {
  return /^(?:\d{1,3}\.){3}\d{1,3}$/.test(hostname);
}

function ipv4ToInt(ip: string): number | null {
  const parts = ip.split(".").map((x) => Number(x));
  if (parts.length !== 4 || parts.some((x) => !Number.isInteger(x) || x < 0 || x > 255)) {
    return null;
  }
  return (((parts[0] << 24) >>> 0) + (parts[1] << 16) + (parts[2] << 8) + parts[3]) >>> 0;
}

function isPrivateOrLocalIPv4(hostname: string): boolean {
  const ipInt = ipv4ToInt(hostname);
  if (ipInt === null) return false;

  const inRange = (start: string, end: string): boolean => {
    const s = ipv4ToInt(start)!;
    const e = ipv4ToInt(end)!;
    return ipInt >= s && ipInt <= e;
  };

  return (
    inRange("10.0.0.0", "10.255.255.255") ||
    inRange("127.0.0.0", "127.255.255.255") ||
    inRange("169.254.0.0", "169.254.255.255") ||
    inRange("172.16.0.0", "172.31.255.255") ||
    inRange("192.168.0.0", "192.168.255.255") ||
    inRange("0.0.0.0", "0.255.255.255")
  );
}

function isDisallowedHostnameForServerSideFetch(hostname: string): boolean {
  const normalized = hostname.trim().toLowerCase();
  if (!normalized) return true;

  if (
    normalized === "localhost" ||
    normalized === "::1" ||
    normalized === "[::1]" ||
    normalized === "0:0:0:0:0:0:0:1" ||
    normalized === "[0:0:0:0:0:0:0:1]"
  ) {
    return true;
  }

  if (isIPv4Address(normalized) && isPrivateOrLocalIPv4(normalized)) {
    return true;
  }

  return false;
}

export interface RobotsTxtChecker {
  robotsTxtUrl: string;
  robotsTxt: string;
  robots: Robot;
}

export async function fetchRobotsTxt(
  url: string,
  skipTlsVerification: boolean = false,
  abort?: AbortSignal,
): Promise<string> {
  const urlObj = new URL(url);
  if (urlObj.protocol !== "http:" && urlObj.protocol !== "https:") {
    throw new Error("Unsupported URL protocol for robots.txt fetch");
  }
  if (isDisallowedHostnameForServerSideFetch(urlObj.hostname)) {
    throw new Error("Blocked hostname for robots.txt fetch");
  }
  const robotsTxtUrl = `${urlObj.protocol}//${urlObj.host}/robots.txt`;

  let extraArgs: any = {};
  if (skipTlsVerification) {
    extraArgs.httpsAgent = new https.Agent({
      rejectUnauthorized: false,
    });
  }

  const response = await axios.get(robotsTxtUrl, {
    timeout: axiosTimeout,
    signal: abort,
    ...extraArgs,
  });

  const contentType = (Object.entries(response.headers).find(
    (x) => x[0].toLowerCase() === "content-type",
  ) ?? [])[1] ?? "";

  if (contentType.includes("text/html") || 
      contentType.includes("application/json") ||
      contentType.includes("application/xml")) {
    return "";
  }

  return response.data;
}

export function createRobotsChecker(
  url: string,
  robotsTxt: string,
): RobotsTxtChecker {
  const urlObj = new URL(url);
  const robotsTxtUrl = `${urlObj.protocol}//${urlObj.host}/robots.txt`;
  const robots = robotsParser(robotsTxtUrl, robotsTxt);
  return {
    robotsTxtUrl,
    robotsTxt,
    robots,
  };
}

export function isUrlAllowedByRobots(
  url: string,
  robots: Robot | null,
  userAgents: string[] = ["FireCrawlAgent", "FirecrawlAgent"],
): boolean {
  if (!robots) return true;

  for (const userAgent of userAgents) {
    let isAllowed = robots.isAllowed(url, userAgent);
    
    // Handle null/undefined responses - default to true (allowed)
    if (isAllowed === null || isAllowed === undefined) {
      isAllowed = true;
    }

    if (isAllowed == null) {
      isAllowed = true;
    }

    // Also check with trailing slash if URL doesn't have one
    // This catches cases like "Disallow: /path/" when user requests "/path"
    if (isAllowed && !url.endsWith("/")) {
      const urlWithSlash = url + "/";
      let isAllowedWithSlash = robots.isAllowed(urlWithSlash, userAgent);
      
      if (isAllowedWithSlash == null) {
        isAllowedWithSlash = true;
      }
      
      // If the trailing slash version is explicitly disallowed, block it
      if (isAllowedWithSlash === false) {
        isAllowed = false;
      }
    }

    if (isAllowed) {
      //   console.log("isAllowed: true, " + userAgent);
      return true;
    }
  }

  return false;
}

export async function checkRobotsTxt(
  url: string,
  skipTlsVerification: boolean = false,
  logger?: Logger,
  abort?: AbortSignal,
): Promise<boolean> {
  try {
    const robotsTxt = await fetchRobotsTxt(url, skipTlsVerification, abort);
    const checker = createRobotsChecker(url, robotsTxt);
    return isUrlAllowedByRobots(url, checker.robots);
  } catch (error) {
    // If we can't fetch robots.txt, assume it's allowed
    logger?.debug("Failed to fetch robots.txt, allowing scrape", {
      error,
      url,
    });
    return true;
  }
}
