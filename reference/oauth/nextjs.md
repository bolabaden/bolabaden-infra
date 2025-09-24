========================
CODE SNIPPETS
========================
TITLE: Protect Express Routes with Middleware
DESCRIPTION: Provides an example of protecting Express.js routes using middleware that checks for a session and redirects to login if not authenticated.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/session-management/protecting.mdx#_snippet_5

LANGUAGE: ts
CODE:
```
import { getSession } from "@auth/express"

export async function authenticatedUser(
  req: Request,
  res: Response,
  next: NextFunction
) {
  const session = res.locals.session ?? (await getSession(req, authConfig))
  if (!session?.user) {
    res.redirect("/login")
  } else {
    next()
  }
}
```

LANGUAGE: ts
CODE:
```
import { authenticatedUser } from "./lib.ts"

// This route is protected
app.get("/profile", authenticatedUser, (req, res) => {
  const { session } = res.locals
  res.render("profile", { user: session?.user })
})

// This route is not protected
app.get("/", (req, res) => {
  res.render("index")
})

app.use("/", root)

```

----------------------------------------

TITLE: Example sendVerificationRequest Implementation
DESCRIPTION: Provides an example implementation for the `sendVerificationRequest` function. This function makes an API call to Forward Email to send the verification email, including HTML and plain text versions.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/forwardemail.mdx#_snippet_3

LANGUAGE: ts
CODE:
```
export async function sendVerificationRequest(params) {
  const { identifier: to, provider, url, theme } = params
  const { host } = new URL(url)
  const res = await fetch("https://api.forwardemail.net/v1/emails", {
    method: "POST",
    headers: {
      Authorization: `Basic ${btoa(provider.apiKey + ":")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: provider.from,
      to,
      subject: `Sign in to ${host}`,
      html: html({ url, host, theme }),
      text: text({ url, host }),
    }),
  })

  if (!res.ok)
    throw new Error("Forward Email error: " + JSON.stringify(await res.json()))
}

function html(params: { url: string; host: string; theme: Theme }) {
  const { url, host, theme } = params

  const escapedHost = host.replace(/\./g, "&#8203;.")

  const brandColor = theme.brandColor || "#346df1"
  const color = {
    background: "#f9f9f9",
    text: "#444",
    mainBackground: "#fff",
    buttonBackground: brandColor,
    buttonBorder: brandColor,
    buttonText: theme.buttonText || "#fff",
  }

  return `
<body style="background: ${color.background};">
  <table width="100%" border="0" cellspacing="20" cellpadding="0"
    style="background: ${color.mainBackground}; max-width: 600px; margin: auto; border-radius: 10px;">
    <tr>
      <td align="center"
        style="padding: 10px 0px; font-size: 22px; font-family: Helvetica, Arial, sans-serif; color: ${color.text};">
        Sign in to <strong>${escapedHost}</strong>
      </td>
    </tr>
    <tr>
      <td align="center" style="padding: 20px 0;">
        <table border="0" cellspacing="0" cellpadding="0">
          <tr>
            <td align="center" style="border-radius: 5px;" bgcolor="${color.buttonBackground}"><a href="${url}"
                target="_blank"
                style="font-size: 18px; font-family: Helvetica, Arial, sans-serif; color: ${color.buttonText}; text-decoration: none; border-radius: 5px; padding: 10px 20px; border: 1px solid ${color.buttonBorder}; display: inline-block; font-weight: bold;">Sign
                in</a></td>
          </tr>
        </table>
      </td>
    </tr>
    <tr>
      <td align="center"
        style="padding: 0px 0px 10px 0px; font-size: 16px; line-height: 22px; font-family: Helvetica, Arial, sans-serif; color: ${color.text};">
        If you did not request this email you can safely ignore it.
      </td>
    </tr>
  </table>
</body>
`
}

// Email Text body (fallback for email clients that don't render HTML, e.g. feature phones)
function text({ url, host }: { url: string; host: string }) {
  return `Sign in to ${host}\n${url}\n\n`
}
```

----------------------------------------

TITLE: Next.js Middleware: Authorized Callback
DESCRIPTION: Configures Next.js middleware with an `authorized` callback in `auth.ts`. This callback determines if a user is authenticated, allowing or denying access based on session status.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/session-management/protecting.mdx#_snippet_11

LANGUAGE: ts
CODE:
```
import NextAuth from "next-auth"

export const { auth, handlers } = NextAuth({
  callbacks: {
    authorized: async ({ auth }) => {
      // Logged in users are authenticated, otherwise redirect to login page
      return !!auth
    },
  },
})
```

----------------------------------------

TITLE: Next.js Middleware: Redirect Unauthenticated
DESCRIPTION: Implements custom logic within Next.js middleware to redirect unauthenticated users to a login page. It checks for the presence of `req.auth` and redirects if not found, unless the path is already the login page.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/session-management/protecting.mdx#_snippet_12

LANGUAGE: ts
CODE:
```
import { auth } from "@/auth"

export default auth((req) => {
  if (!req.auth && req.nextUrl.pathname !== "/login") {
    const newUrl = new URL("/login", req.nextUrl.origin)
    return Response.redirect(newUrl)
  }
})
```

----------------------------------------

TITLE: Environment Variable Configuration
DESCRIPTION: Sets the API key for the Forward Email provider. This key is required for authentication and should be stored securely as an environment variable.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/forwardemail.mdx#_snippet_0

LANGUAGE: sh
CODE:
```
AUTH_FORWARDEMAIL_KEY=abc
```

----------------------------------------

TITLE: Configure Mailru Provider in Express
DESCRIPTION: Demonstrates integrating the Mailru OAuth provider into an Express.js application using ExpressAuth. This snippet illustrates how to use the ExpressAuth middleware and include the Mailru provider for authentication flows.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/mailru.mdx#_snippet_5

LANGUAGE: ts
CODE:
```
import { ExpressAuth } from "@auth/express"
import MailRu from "@auth/express/providers/mailru"

app.use("/auth/*", ExpressAuth({ providers: [MailRu] }))
```

----------------------------------------

TITLE: Setup NextAuth.js with Next.js
DESCRIPTION: Demonstrates the setup for NextAuth.js within a Next.js application. It includes the core authentication configuration file (`auth.ts`) and the necessary middleware setup (`middleware.ts`) for routing.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/index.mdx#_snippet_3

LANGUAGE: typescript
CODE:
```
// auth.ts
import NextAuth from "next-auth"
import GitHub from "next-auth/providers/github"
export const { auth, handlers } = NextAuth({ providers: [GitHub] })

// middleware.ts
export { auth as middleware } from "@/auth"

// app/api/auth/[...nextauth]/route.ts
import { handlers } from "@/auth"
export const { GET, POST } = handlers

```

----------------------------------------

TITLE: Express Auth0 Provider Configuration
DESCRIPTION: Integrates the Auth0 provider into an Express.js application using ExpressAuth. This configuration applies the authentication middleware to specific routes, enabling Auth0 authentication for those paths.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/auth0.mdx#_snippet_5

LANGUAGE: typescript
CODE:
```
import { ExpressAuth } from "@auth/express"
import Auth0 from "@auth/express/providers/auth0"

app.use("/auth/*", ExpressAuth({ providers: [Auth0] }))
```

----------------------------------------

TITLE: Configure Mailru Provider in SvelteKit
DESCRIPTION: Shows how to add the Mailru OAuth provider to a SvelteKit project with SvelteKitAuth. This configuration enables Mailru authentication by importing the provider and passing it to the SvelteKitAuth constructor.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/mailru.mdx#_snippet_4

LANGUAGE: ts
CODE:
```
import { SvelteKitAuth } from "@auth/sveltekit"
import MailRu from "@auth/sveltekit/providers/mailru"

export const { handle, signIn, signOut } = SvelteKitAuth({
  providers: [MailRu],
})
```

----------------------------------------

TITLE: Configure Medium Provider in SvelteKit
DESCRIPTION: Illustrates how to add the Medium OAuth provider to a SvelteKit application using SvelteKitAuth. This setup enables authentication flows with Medium.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/medium.mdx#_snippet_3

LANGUAGE: ts
CODE:
```
import { SvelteKitAuth } from "@auth/sveltekit"
import Medium from "@auth/sveltekit/providers/medium"

export const { handle, signIn, signOut } = SvelteKitAuth({
  providers: [Medium],
})
```

----------------------------------------

TITLE: NextAuth.js JWT Strategy: Google OAuth Token Refresh
DESCRIPTION: This TypeScript code demonstrates how to implement token refresh logic within NextAuth.js using the JWT strategy. It utilizes the `jwt` callback to store OAuth tokens and the `session` callback to propagate potential refresh errors. The example specifically shows how to refresh an expired Google OAuth access token by making a POST request to the Google token endpoint, requiring `AUTH_GOOGLE_ID` and `AUTH_GOOGLE_SECRET` environment variables.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/guides/refresh-token-rotation.mdx#_snippet_0

LANGUAGE: typescript
CODE:
```
import NextAuth, { type User } from "next-auth"
import Google from "next-auth/providers/google"

export const { handlers, auth } = NextAuth({
  providers: [
    Google({
      // Google requires "offline" access_type to provide a `refresh_token`
      authorization: { params: { access_type: "offline", prompt: "consent" } },
    }),
  ],
  callbacks: {
    async jwt({ token, account }) {
      if (account) {
        // First-time login, save the `access_token`, its expiry and the `refresh_token`
        return {
          ...token,
          access_token: account.access_token,
          expires_at: account.expires_at,
          refresh_token: account.refresh_token,
        }
      } else if (Date.now() < token.expires_at * 1000) {
        // Subsequent logins, but the `access_token` is still valid
        return token
      } else {
        // Subsequent logins, but the `access_token` has expired, try to refresh it
        if (!token.refresh_token) throw new TypeError("Missing refresh_token")

        try {
          // The `token_endpoint` can be found in the provider's documentation. Or if they support OIDC,
          // at their `/.well-known/openid-configuration` endpoint.
          // i.e. https://accounts.google.com/.well-known/openid-configuration
          const response = await fetch("https://oauth2.googleapis.com/token", {
            method: "POST",
            body: new URLSearchParams({
              client_id: process.env.AUTH_GOOGLE_ID!,
              client_secret: process.env.AUTH_GOOGLE_SECRET!,
              grant_type: "refresh_token",
              refresh_token: token.refresh_token!,
            }),
          })

          const tokensOrError = await response.json()

          if (!response.ok) throw tokensOrError

          const newTokens = tokensOrError as {
            access_token: string
            expires_in: number
            refresh_token?: string
          }

          return {
            ...token,
            access_token: newTokens.access_token,
            expires_at: Math.floor(Date.now() / 1000 + newTokens.expires_in),
            // Some providers only issue refresh tokens once, so preserve if we did not get a new one
            refresh_token: newTokens.refresh_token
              ? newTokens.refresh_token
              : token.refresh_token,
          }
        } catch (error) {
          console.error("Error refreshing access_token", error)
          // If we fail to refresh the token, return an error so we can handle it on the page
          token.error = "RefreshTokenError"
          return token
        }
      }
    },
    async session({ session, token }) {
      session.error = token.error
      return session
    },
  },
})

declare module "next-auth" {
  interface Session {
    error?: "RefreshTokenError"
  }
}

declare module "next-auth/jwt" {
  interface JWT {
    access_token: string
    expires_at: number
    refresh_token?: string
    error?: "RefreshTokenError"
  }
}

```

----------------------------------------

TITLE: Express: Setup MikroORM Adapter
DESCRIPTION: Configures Express.js applications to use the MikroORM adapter for authentication. It sets up middleware with adapter configuration, including database connection details.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/adapters/mikro-orm.mdx#_snippet_5

LANGUAGE: ts
CODE:
```
import { ExpressAuth } from "@auth/express"
import { MikroOrmAdapter } from "@auth/mikro-orm-adapter"

const app = express()

app.set("trust proxy", true)
app.use(
  "/auth/*",
  ExpressAuth({
    providers: [],
    adapter: MikroOrmAdapter({
      // MikroORM options object - https://mikro-orm.io/docs/next/configuration#driver
      dbName: process.env.DATABASE_CONNECTION_STRING,
      type: "sqlite",
      debug: true,
    }),
  })
)
```

----------------------------------------

TITLE: Configure Medium Provider in Qwik
DESCRIPTION: Shows how to integrate the Medium OAuth provider within a Qwik application using QwikAuth. This configuration sets up the necessary providers for authentication.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/medium.mdx#_snippet_2

LANGUAGE: ts
CODE:
```
import { QwikAuth$ } from "@auth/qwik"
import Medium from "@auth/qwik/providers/medium"

export const { onRequest, useSession, useSignIn, useSignOut } = QwikAuth$(
  () => ({
    providers: [Medium],
  })
)
```

----------------------------------------

TITLE: Express Zoho Provider Configuration
DESCRIPTION: Integrates the Zoho provider with ExpressAuth for an Express.js application. This example shows how to use the ExpressAuth middleware and configure it with the Zoho provider for handling authentication routes.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/zoho.mdx#_snippet_5

LANGUAGE: ts
CODE:
```
import { ExpressAuth } from "@auth/express"
import Zoho from "@auth/express/providers/zoho"

app.use("/auth/*", ExpressAuth({ providers: [Zoho] }))
```

----------------------------------------

TITLE: Configure EVEOnline Provider in Express
DESCRIPTION: Provides an example of how to set up the EVEOnline OAuth provider for an Express.js application using ExpressAuth. It shows how to use the middleware for authentication routes.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/eveonline.mdx#_snippet_5

LANGUAGE: ts
CODE:
```
import { ExpressAuth } from "@auth/express"
import EveOnline from "@auth/express/providers/eve-online"

app.use("/auth/*", ExpressAuth({ providers: [EveOnline] }))
```

----------------------------------------

TITLE: GitHub OAuth Callback URLs for Frameworks
DESCRIPTION: Defines the callback URLs required for GitHub OAuth integration, which vary slightly based on the framework used. These URLs are registered in the GitHub OAuth App settings to handle the redirect after user authentication.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/guides/configuring-github.mdx#_snippet_3

LANGUAGE: bash
CODE:
```
// Local
http://localhost:3000/api/auth/callback/github

// Prod
https://app.company.com/api/auth/callback/github
```

LANGUAGE: bash
CODE:
```
// Local
http://localhost:3000/auth/callback/github

// Prod
https://app.company.com/auth/callback/github
```

LANGUAGE: bash
CODE:
```
// Local
http://localhost:3000/auth/callback/github

// Prod
https://app.company.com/auth/callback/github
```

LANGUAGE: bash
CODE:
```
// Local
http://localhost:3000/auth/callback/github

// Prod
https://app.company.com/auth/callback/github
```

----------------------------------------

TITLE: Configure Credentials Provider Across Frameworks
DESCRIPTION: Set up the Credentials provider for custom authentication flows, supporting username/password or other arbitrary credentials. The `authorize` function handles credential verification and returns user data or null on failure. This configuration is shown for Next.js, Qwik, SvelteKit, and Express.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/credentials.mdx#_snippet_0

LANGUAGE: typescript
CODE:
```
import NextAuth from "next-auth"
import Credentials from "next-auth/providers/credentials"

export const { signIn, signOut, auth } = NextAuth({
  providers: [
    Credentials({
      credentials: {
        username: { label: "Username" },
        password: { label: "Password", type: "password" },
      },
      async authorize({ request }) {
        const response = await fetch(request)
        if (!response.ok) return null
        return (await response.json()) ?? null
      },
    }),
  ],
})
```

LANGUAGE: typescript
CODE:
```
import { QwikAuth$ } from "@auth/qwik"
import Credentials from "@auth/qwik/providers/credentials"

export const { onRequest, useSession, useSignIn, useSignOut } = QwikAuth$(
  () => ({
    providers: [
      Credentials({
        credentials: {
          username: { label: "Username" },
          password: { label: "Password", type: "password" },
        },
        async authorize({ request }) {
          const response = await fetch(request)
          if (!response.ok) return null
          return (await response.json()) ?? null
        },
      }),
    ],
  })
)
```

LANGUAGE: typescript
CODE:
```
import { SvelteKitAuth } from "@auth/sveltekit"
import Credentials from "@auth/sveltekit/providers/credentials"

export const { handle, signIn, signOut } = SvelteKitAuth({
  providers: [
    Credentials({
      credentials: {
        username: { label: "Username" },
        password: { label: "Password", type: "password" },
      },
      async authorize({ request }) {
        const response = await fetch(request)
        if (!response.ok) return null
        return (await response.json()) ?? null
      },
    }),
  ],
})
```

LANGUAGE: typescript
CODE:
```
import { ExpressAuth } from "@auth/express";
import Credentials from "@auth/express/providers/credentials";

app.use("/auth/*", ExpressAuth({
  providers: [
    Credentials({
      credentials: {
        username: { label: "Username" },
        password: { label: "Password", type: "password" },
      },
      async authorize({ request }) {
        const response = await fetch(request);
        if (!response.ok) return null;
        return (await response.json()) ?? null;
      },
    }),
  ],
});
```

----------------------------------------

TITLE: Setup NextAuth.js with Express
DESCRIPTION: Illustrates how to set up NextAuth.js within an Express.js application. It shows the usage of the Express adapter for integrating authentication middleware.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/index.mdx#_snippet_5

LANGUAGE: typescript
CODE:
```
// server.ts
import { express } from "express"
import { ExpressAuth } from "@auth/express"
import GitHub from "@auth/express/providers/github"

const app = express()

app.use("/auth/\*", ExpressAuth({ providers: [GitHub] }))

```

----------------------------------------

TITLE: Using auth() in API Routes (Pages Router)
DESCRIPTION: Explains how to use the `auth()` function within API routes in the Pages Router, replacing `getServerSession` and `getToken`. Passing `req` and `res` to `auth()` rotates session expiry.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/migrating-to-v5.mdx#_snippet_7

LANGUAGE: diff
CODE:
```
- import { getServerSession } from "next-auth/next"
- import { getToken } from "next-auth/jwt"
- import { authOptions } from "pages/api/auth/[...nextauth]"
+ import { auth } from "@/auth"
+ import { NextApiRequest, NextApiResponse } from "next"

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
-  const session = await getServerSession(req, res, authOptions)
-  const token = await getToken({ req })
+  const session = await auth(req, res)
  if (session) return res.json("Success")
  return res.status(401).json("You must be logged in.")
}
```

----------------------------------------

TITLE: Protect SvelteKit API Route
DESCRIPTION: Explains how to protect SvelteKit API routes by accessing the session via `event.locals.auth()` in `+server.ts` files. It checks for user authentication before proceeding.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/session-management/protecting.mdx#_snippet_9

LANGUAGE: ts
CODE:
```
import type { RequestHandler } from "./$types"

export const GET: RequestHandler = async (event) => {
  const session = await event.locals.auth()

  if (!session?.user?.userId) {
    return new Response(null, { status: 401, statusText: "Unauthorized" })
  }
}
```

----------------------------------------

TITLE: Configure SvelteKit OAuth Providers with Standard Env Vars
DESCRIPTION: Illustrates automatic inference of OAuth credentials for SvelteKit applications using environment variables like AUTH_[PROVIDER]_ID and AUTH_[PROVIDER]_SECRET in the SvelteKitAuth configuration.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/guides/environment-variables.mdx#_snippet_6

LANGUAGE: typescript
CODE:
```
import SvelteKitAuth from "@auth/sveltekit"
import Google from "@auth/sveltekit/providers/google"
import Twitter from "@auth/sveltekit/providers/twitter"
import GitHub from "@auth/sveltekit/providers/github"

export const { handle } = SvelteKitAuth({
  providers: [Google, Twitter, GitHub],
})
```

----------------------------------------

TITLE: Configure Backend Authorization with Express.js and Keycloak
DESCRIPTION: An example of configuring an Express.js backend to authorize incoming requests using JWT verification, specifically integrating with Keycloak for token validation.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/guides/integrating-third-party-backends.mdx#_snippet_3

LANGUAGE: javascript
CODE:
```
const app = express()
const jwtCheck = jwt({
  secret: jwks.expressJwtSecret({
    cache: true,
    rateLimit: true,
    jwksRequestsPerMinute: 5,
    jwksUri:
      "https://keycloak.authjs.dev/realms/master/protocol/openid-connect/certs",
  }),
  issuer: "https://keycloak.authjs.dev/realms/master",
  algorithms: ["RS256"],
})
app.get("*", jwtCheck, (req, res) => {
  const name = req.auth?.name ?? "unknown name"
  res.json({ greeting: `Hello, ${name}!` })
})
// ...
```

----------------------------------------

TITLE: Setup ForwardEmail Provider in SvelteKit
DESCRIPTION: Configures the ForwardEmail provider for SvelteKitAuth.js. This involves importing SvelteKitAuth and the ForwardEmail provider, then including ForwardEmail in the providers array within the SvelteKitAuth configuration. It also includes a hook to export the handle function.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/authentication/email.mdx#_snippet_3

LANGUAGE: ts
CODE:
```
import SvelteKitAuth from "@auth/sveltekit"
import ForwardEmail from "@auth/sveltekit/providers/forwardemail"

export const { handle, signIn, signOut } = SvelteKitAuth({
  providers: [ForwardEmail],
})
```

LANGUAGE: ts
CODE:
```
export { handle } from "./auth"
```

----------------------------------------

TITLE: GitLab OAuth Environment Variables
DESCRIPTION: Lists the environment variables required to configure the GitLab OAuth provider. These variables store your GitLab application's client ID and secret, which are essential for secure authentication.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/gitlab.mdx#_snippet_1

LANGUAGE: bash
CODE:
```
AUTH_GITLAB_ID
AUTH_GITLAB_SECRET
```

----------------------------------------

TITLE: Override generateVerificationToken in NextAuth.js
DESCRIPTION: Shows how to override the default verification token generation mechanism in NextAuth.js. This example uses `crypto.randomUUID()` to create a unique token.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/forwardemail.mdx#_snippet_4

LANGUAGE: ts
CODE:
```
import NextAuth from "next-auth"
import ForwardEmail from "next-auth/providers/forwardemail"

export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [
    ForwardEmail({
      async generateVerificationToken() {
        return crypto.randomUUID()
      },
    }),
  ],
})
```

----------------------------------------

TITLE: Configure NextAuth.js with Microsoft Entra ID (Express)
DESCRIPTION: Provides an example of integrating NextAuth.js with Microsoft Entra ID for an Express.js application. It uses the ExpressAuth middleware and requires environment variables for authentication.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/microsoft-entra-id.mdx#_snippet_5

LANGUAGE: typescript
CODE:
```
import { ExpressAuth } from "@auth/express"
import MicrosoftEntraID from "@auth/express/providers/microsoft-entra-id"

app.use(
  "/auth/*",
  ExpressAuth({
    providers: [
      MicrosoftEntraID({
        clientId: process.env.AUTH_MICROSOFT_ENTRA_ID_ID,
        clientSecret: process.env.AUTH_MICROSOFT_ENTRA_ID_SECRET,
        issuer: process.env.AUTH_MICROSOFT_ENTRA_ID_ISSUER,
      }),
    ],
  })
)
```

----------------------------------------

TITLE: Setup ForwardEmail Provider in Qwik
DESCRIPTION: Configures the ForwardEmail provider for QwikAuth.js. This involves importing QwikAuth$ and the ForwardEmail provider, then including ForwardEmail in the providers array within the QwikAuth configuration.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/authentication/email.mdx#_snippet_2

LANGUAGE: ts
CODE:
```
import { QwikAuth$ } from "@auth/qwik"
import ForwardEmail from "@auth/qwik/providers/forwardemail"

export const { onRequest, useSession, useSignIn, useSignOut } = QwikAuth$(
  () => ({
    providers: [ForwardEmail],
  })
)
```

----------------------------------------

TITLE: Implement sendVerificationRequest with SendGrid API
DESCRIPTION: Provides a basic implementation of the `sendVerificationRequest` function using the SendGrid API to send a plain text email with an authentication link. It includes error handling for the API response.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/guides/configuring-http-email.mdx#_snippet_1

LANGUAGE: ts
CODE:
```
export async function sendVerificationRequest({ identifier: email, url }) {
  // Call the cloud Email provider API for sending emails
  const response = await fetch("https://api.sendgrid.com/v3/mail/send", {
    // The body format will vary depending on provider, please see their documentation
    body: JSON.stringify({
      personalizations: [{ to: [{ email }] }],
      from: { email: "noreply@company.com" },
      subject: "Sign in to Your page",
      content: [
        {
          type: "text/plain",
          value: `Please click here to authenticate - ${url}`,
        },
      ],
    }),
    headers: {
      // Authentication will also vary from provider to provider, please see their docs.
      Authorization: `Bearer ${process.env.SENDGRID_API}`,
      "Content-Type": "application/json",
    },
    method: "POST",
  })

  if (!response.ok) {
    const { errors } = await response.json()
    throw new Error(JSON.stringify(errors))
  }
}
```

----------------------------------------

TITLE: SimpleLogin Callback URLs
DESCRIPTION: Specifies the callback URLs required by SimpleLogin for OAuth authentication. These URLs are used by SimpleLogin to redirect the user back to your application after successful authentication. Ensure these match your application's deployment environment.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/simplelogin.mdx#_snippet_0

LANGUAGE: bash
CODE:
```
https://example.com/api/auth/callback/simplelogin
```

LANGUAGE: bash
CODE:
```
https://example.com/auth/callback/simplelogin
```

----------------------------------------

TITLE: Configure Qwik OAuth Providers with Standard Env Vars
DESCRIPTION: Shows the automatic inference of OAuth credentials for Qwik applications using environment variables like AUTH_[PROVIDER]_ID and AUTH_[PROVIDER]_SECRET within the QwikAuth$ setup.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/guides/environment-variables.mdx#_snippet_4

LANGUAGE: typescript
CODE:
```
import { QwikAuth$ } from "@auth/qwik"
import Google from "@auth/qwik/providers/google"
import Twitter from "@auth/qwik/providers/twitter"
import GitHub from "@auth/qwik/providers/github"

export const {onRequest, useSession, useSignIn, useSignOut } = QwikAuth$(
  () => ({
    providers: [Google, Twitter, GitHub],
  })
)
```

----------------------------------------

TITLE: Using auth() in getServerSideProps (Pages Router)
DESCRIPTION: Demonstrates using the `auth()` function within `getServerSideProps` in the Pages Router to fetch session data, replacing `getServerSession` and `getToken`. Passing `context.res` rotates session expiry.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/migrating-to-v5.mdx#_snippet_8

LANGUAGE: diff
CODE:
```
- import { getServerSession } from "next-auth/next"
- import { getToken } from "next-auth/jwt"
- import { authOptions } from "pages/api/auth/[...nextauth]"
+ import { auth } from "@/auth"

export const getServerSideProps: GetServerSideProps = async (context) => {
-  const session = await getServerSession(context.req, context.res, authOptions)
-  const token = await getToken({ req: context.req })
+  const session = await auth(context)
  if (session) {
    // Do something with the session
  }

  return { props: { session } }
}
```

----------------------------------------

TITLE: Make Authorized API Requests
DESCRIPTION: Demonstrates how to make an authorized API request using the access token stored in the session. It's recommended to handle this server-side, for example, in a Route Handler.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/guides/integrating-third-party-backends.mdx#_snippet_2

LANGUAGE: typescript
CODE:
```
export async function handler(request: NextRequest) {
  const session = await auth()
  return await fetch(/*<your-backend-url>/api/authenticated/greeting*/, {
    headers: { "Authorization":  `Bearer ${session?.accessToken}` }
  })
  // ...
```

----------------------------------------

TITLE: NextAuth.js Authentication Methods Comparison
DESCRIPTION: This documentation outlines the evolution of authentication methods in NextAuth.js from version 4 to version 5. It details how common authentication tasks are handled across various application contexts, including Server Components, Middleware, Client Components, Route Handlers, API Routes, and server-side rendering functions like getServerSideProps.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/migrating-to-v5.mdx#_snippet_3

LANGUAGE: APIDOC
CODE:
```
NextAuth.js Authentication Methods (v4 vs v5)

This section details the changes in authentication handling from NextAuth.js v4 to v5.

**Core Authentication Functions:**

1.  **`getServerSession` (v4) / `auth` (v5)**
    *   **Purpose**: Retrieves the current session or user information.
    *   **v4 Usage**: Requires explicit passing of `authOptions` and request/response objects in certain contexts.
        *   Server Component: `getServerSession(authOptions)`
        *   API Route (Node.js): `getServerSession(req, res, authOptions)`
        *   getServerSideProps: `getServerSession(ctx.req, ctx.res, authOptions)`
    *   **v5 Usage**: Provides a more unified and often context-aware approach.
        *   Server Component: `auth()` call
        *   API Route (Node.js): `auth(req, res)` call
        *   getServerSideProps: `auth(ctx)` call
        *   Route Handler/API Route (Edge): `auth()` wrapper
    *   **Parameters (v4)**:
        *   `authOptions`: Configuration object for NextAuth.js.
        *   `req`: Node.js HTTP request object.
        *   `res`: Node.js HTTP response object.
        *   `ctx`: Context object for `getServerSideProps`.
    *   **Parameters (v5)**:
        *   `req`, `res`: Node.js HTTP request/response objects (for API Routes).
        *   `ctx`: Context object for `getServerSideProps`.
        *   (Implicitly handles context in Server Components and Middleware).
    *   **Return Value**: Session object or null if not authenticated.

2.  **`withAuth` (v4) / `auth` (v5)**
    *   **Purpose**: Middleware protection or wrapping handlers.
    *   **v4 Usage**: A higher-order component (HOC) or wrapper function.
        *   Middleware: `withAuth(middleware, subset of authOptions)`
    *   **v5 Usage**: The `auth` export can be used as a wrapper.
        *   Middleware: `auth` export / `auth()` wrapper
        *   Route Handler: `auth()` wrapper
    *   **Parameters**: Varies based on context and version.

3.  **`useSession` (v4 & v5)**
    *   **Purpose**: Hook for accessing session data in Client Components.
    *   **Usage**: `useSession()` hook
    *   **Description**: Remains consistent across v4 and v5 for client-side state management.

4.  **`getToken` (v4)**
    *   **Purpose**: Retrieves JWT tokens, often without session rotation.
    *   **v4 Usage**: `getToken(req)` or `getToken(ctx.req)`
    *   **Note**: In v5, `auth(req, res)` or `auth(ctx)` typically handles token retrieval as part of the session object.

**Summary Table:**

| Where                   | v4                                                    | v5                               |
| ----------------------- | ----------------------------------------------------- | -------------------------------- |
| **Server Component**    | `getServerSession(authOptions)`                       | `auth()` call                    |
| **Middleware**          | `withAuth(middleware, subset of authOptions)` wrapper | `auth` export / `auth()` wrapper |
| **Client Component**    | `useSession()` hook                                   | `useSession()` hook              |
| **Route Handler**       | _Previously not supported_                            | `auth()` wrapper                 |
| **API Route (Edge)**    | _Previously not supported_                            | `auth()` wrapper                 |
| **API Route (Node.js)** | `getServerSession(req, res, authOptions)`             | `auth(req, res)` call            |
| **API Route (Node.js)** | `getToken(req)` (No session rotation)                 | `auth(req, res)` call            |
| **getServerSideProps**  | `getServerSession(ctx.req, ctx.res, authOptions)`     | `auth(ctx)` call                 |
| **getServerSideProps**  | `getToken(ctx.req)` (No session rotation)             | `auth(req, res)` call            |
```

----------------------------------------

TITLE: Qwik Request Handling with Session
DESCRIPTION: Shows how to implement request handling in Qwik, checking for a valid session and redirecting unauthenticated users to the sign-in page. This is typically done in a plugin.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/guides/role-based-access-control.mdx#_snippet_6

LANGUAGE: typescript
CODE:
```
import { type RequestHandler } from '@builder.io/qwik-city';

export const onRequest: RequestHandler = (event) => {
  const session = event.sharedMap.get("session")
  if (!session || new Date(session.expires) < new Date()) {
    throw event.redirect(302, `/auth/signin?redirectTo=${event.url.pathname}`)
  }

  return session
}
```

----------------------------------------

TITLE: Add Signin Button (Qwik)
DESCRIPTION: Shows how to implement a signin button in a Qwik application using the `useSignIn` hook from the authentication plugin.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/authentication/email.mdx#_snippet_13

LANGUAGE: ts
CODE:
```
import { component$ } from "@builder.io/qwik"
import { useSignIn } from "./plugin@auth"

export default component$(() => {
  const signInSig = useSignIn()

  return (
    <button
      onClick$={() => signInSig.submit({ redirectTo: "/" })}
    >
      SignIn
    </button>
  )
})
```

----------------------------------------

TITLE: Configure SailPoint OAuth Provider
DESCRIPTION: Enables SailPoint OAuth authentication by configuring the provider within NextAuth.js. This involves specifying client credentials, authorization endpoints, token URLs, userinfo endpoints, and a profile mapping function. Environment variables are used for sensitive information.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/sailpoint.mdx#_snippet_2

LANGUAGE: ts
CODE:
```
import NextAuth from "next-auth"

export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [
    {
      id: "sailpoint",
      name: "SailPoint",
      type: "oauth",
      clientId: process.env.AUTH_SAILPOINT_ID!,
      clientSecret: process.env.AUTH_SAILPOINT_SECRET!,
      authorization: {
        url: `${process.env.AUTH_SAILPOINT_BASE_URL!}/oauth/authorize`,
        params: { scope: "sp:scopes:all" },
      },
      token: `${process.env.AUTH_SAILPOINT_BASE_API_URL!}/oauth/token`,
      userinfo: `${process.env.AUTH_SAILPOINT_BASE_API_URL!}/oauth/userinfo`,
      profile(profile) {
        return {
          id: profile.id,
          email: profile.email,
          name: profile.uid,
          image: null,
        }
      },
      style: { brandColor: "#011E69", logo: "sailpoint.svg" },
    },
  ],
})
```

LANGUAGE: ts
CODE:
```
import { QwikAuth$ } from "@auth/qwik"

export const { onRequest, useSession, useSignIn, useSignOut } = QwikAuth$(
  () => ({
    providers: [
      {
        id: "sailpoint",
        name: "SailPoint",
        type: "oauth",
        clientId: import.meta.env.AUTH_SAILPOINT_ID!,
        clientSecret: import.meta.env.AUTH_SAILPOINT_SECRET!,
        authorization: {
          url: `${import.meta.env.AUTH_SAILPOINT_BASE_URL!}/oauth/authorize`,
          params: { scope: "sp:scopes:all" },
        },
        token: `${import.meta.env.AUTH_SAILPOINT_BASE_API_URL!}/oauth/token`,
        userinfo: `${import.meta.env.AUTH_SAILPOINT_BASE_API_URL!}/oauth/userinfo`,
        profile(profile) {
          return {
            id: profile.id,
            email: profile.email,
            name: profile.uid,
            image: null,
          }
        },
        style: { brandColor: "#011E69", logo: "sailpoint.svg" },
      },
    ],
  })
)
```

LANGUAGE: ts
CODE:
```
import { SvelteKitAuth } from "@auth/sveltekit"
import { env } from "$env/dynamic/prviate"

export const { handle, signIn, signOut } = SvelteKitAuth({
  providers: [
    {
      id: "sailpoint",
      name: "SailPoint",
      type: "oauth",
      clientId: env.AUTH_SAILPOINT_ID!,
      clientSecret: env.AUTH_SAILPOINT_SECRET!,
      authorization: {
        url: `${env.AUTH_SAILPOINT_BASE_URL!}/oauth/authorize`,
        params: { scope: "sp:scopes:all" },
      },
      token: `${env.AUTH_SAILPOINT_BASE_API_URL!}/oauth/token`,
      userinfo: `${env.AUTH_SAILPOINT_BASE_API_URL!}/oauth/userinfo`,
      profile(profile) {
        return {
          id: profile.id,
          email: profile.email,
          name: profile.uid,
          image: null,
        }
      },
      style: { brandColor: "#011E69", logo: "sailpoint.svg" },
    },
  ],
})
```

LANGUAGE: ts
CODE:
```
import { ExpressAuth } from "@auth/express"

app.use(
  "/auth/*",
  ExpressAuth({
    providers: [
      {
        id: "sailpoint",
        name: "SailPoint",
        type: "oauth",
        clientId: process.env.AUTH_SAILPOINT_ID!,
        clientSecret: process.env.AUTH_SAILPOINT_SECRET!,
        authorization: {
          url: `${process.env.AUTH_SAILPOINT_BASE_URL!}/oauth/authorize`,
          params: { scope: "sp:scopes:all" },
        },
        token: `${process.env.AUTH_SAILPOINT_BASE_API_URL!}/oauth/token`,
        userinfo: `${process.env.AUTH_SAILPOINT_BASE_API_URL!}/oauth/userinfo`,
        profile(profile) {
          return {
            id: profile.id,
            email: profile.email,
            name: profile.uid,
            image: null,
          }
        },
        style: { brandColor: "#011E69", logo: "sailpoint.svg" },
      },
    ],
  })
)
```

----------------------------------------

TITLE: Beyond Identity Provider Configuration
DESCRIPTION: Demonstrates how to configure the Beyond Identity provider for various frameworks like Next.js, Qwik, SvelteKit, and Express. This involves importing the provider and adding it to the authentication configuration.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/beyondidentity.mdx#_snippet_1

LANGUAGE: ts
CODE:
```
import NextAuth from "next-auth"
import BeyondIdentity from "next-auth/providers/beyondidentity"

export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [BeyondIdentity],
})
```

LANGUAGE: ts
CODE:
```
import { QwikAuth$ } from "@auth/qwik"
import BeyondIdentity from "@auth/qwik/providers/beyondidentity"

export const { onRequest, useSession, useSignIn, useSignOut } = QwikAuth$(
  () => ({
    providers: [BeyondIdentity],
  })
)
```

LANGUAGE: ts
CODE:
```
import { SvelteKitAuth } from "@auth/sveltekit"
import BeyondIdentity from "@auth/sveltekit/providers/beyondidentity"

export const { handle, signIn, signOut } = SvelteKitAuth({
  providers: [BeyondIdentity],
})
```

LANGUAGE: ts
CODE:
```
import { ExpressAuth } from "@auth/express"
import BeyondIdentity from "@auth/express/providers/beyondidentity"

app.use(
  "/auth/*",
  ExpressAuth({
    providers: [BeyondIdentity],
  })
)
```

----------------------------------------

TITLE: NextAuth.js Provider Configuration
DESCRIPTION: Demonstrates how to configure the Forward Email provider within NextAuth.js. It includes setting the API key and the sender email address ('from'). Examples are provided for Next.js, Qwik, and SvelteKit integration.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/forwardemail.mdx#_snippet_1

LANGUAGE: ts
CODE:
```
import NextAuth from "next-auth"
import ForwardEmail from "next-auth/providers/forwardemail"

export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: ...,
  providers: [
    ForwardEmail({
      // If your environment variable is named differently than default
      apiKey: AUTH_FORWARDEMAIL_KEY,
      from: "no-reply@company.com"
    }),
  ],
})
```

LANGUAGE: ts
CODE:
```
import { QwikAuth$ } from "@auth/qwik"
import ForwardEmail from "@auth/qwik/providers/forwardemail"

export const { onRequest, useSession, useSignIn, useSignOut } = QwikAuth$(
  () => ({
    providers: [
      ForwardEmail({
        // If your environment variable is named differently than default
        apiKey: import.meta.env.AUTH_FORWARDEMAIL_KEY,
        from: "no-reply@company.com",
      }),
    ],
  })
)
```

LANGUAGE: ts
CODE:
```
import { SvelteKitAuth } from "@auth/sveltekit"
import ForwardEmail from "@auth/sveltekit/providers/forwardemail"
import { env } from "$env/dynamic/prviate"

export const { handle, signIn, signOut } = SvelteKitAuth({
  adapter: ...,
  providers: [
    ForwardEmail({
      // If your environment variable is named differently than default
      apiKey: env.AUTH_FORWARDEMAIL_KEY,
      from: "no-reply@company.com",
    }),
  ],
})
```

----------------------------------------

TITLE: Configure Environment Variables
DESCRIPTION: Set up your authentication secret and Resend API key in the `.env.local` file. Ensure AUTH_SECRET is unique and kept confidential. AUTH_RESEND_KEY is required for Resend provider integration.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/guides/configuring-resend.mdx#_snippet_5

LANGUAGE: bash
CODE:
```
AUTH_SECRET="changeMe"

AUTH_RESEND_KEY={apiKey}
```

----------------------------------------

TITLE: Express Configuration with Mastodon
DESCRIPTION: Example configuration for Express.js to integrate the Mastodon OAuth provider. This shows how to use ExpressAuth with the Mastodon provider as middleware.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/mastodon.mdx#_snippet_5

LANGUAGE: ts
CODE:
```
import { ExpressAuth } from "@auth/express"
import Mastodon from "@auth/express/providers/mastodon"

app.use("/auth/*", ExpressAuth({ providers: [Mastodon] }))
```

----------------------------------------

TITLE: Express GitHub Provider Configuration
DESCRIPTION: Example configuration for integrating the GitHub provider with ExpressAuth in an Express.js application. It uses middleware to handle authentication routes.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/github.mdx#_snippet_6

LANGUAGE: ts
CODE:
```
import { ExpressAuth } from "@auth/express"
import GitHub from "@auth/express/providers/github"

app.use("/auth/*", ExpressAuth({ providers: [GitHub] }))
```

----------------------------------------

TITLE: NextAuth.js API Endpoints
DESCRIPTION: Provides an overview of the available API endpoints for authentication operations in NextAuth.js, including session management, OAuth flows, and sign-in/sign-out.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/__wiki__/Home.md#_snippet_0

LANGUAGE: APIDOC
CODE:
```
POST /auth/email/signin
  Description: Initiates the email sign-in process.

GET /auth/email/signin/:token
  Description: Verifies the sign-in token sent via email.

POST /auth/signout
  Description: Logs the user out of the application.

GET /auth/csrf
  Description: Retrieves the CSRF token for security.

GET /auth/session
  Description: Fetches the current user's session data.

GET /auth/linked
  Description: Retrieves information about linked accounts for the user.

GET /auth/oauth/${provider}
  Description: Initiates the OAuth flow for a specific provider.
  Parameters:
    provider: The name of the OAuth provider (e.g., 'google', 'github').

GET /auth/oauth/${provider}/callback
  Description: Handles the callback from the OAuth provider after authentication.
  Parameters:
    provider: The name of the OAuth provider.

POST /auth/oauth/${provider}/unlink
  Description: Unlinks an OAuth account from the user's profile.
  Parameters:
    provider: The name of the OAuth provider.

GET /auth/providers
  Description: Lists all available authentication providers.
```

----------------------------------------

TITLE: Next.js Dynamic Route Handler for Auth.js
DESCRIPTION: Configures the Next.js dynamic route handler (`[...nextauth]/route.ts`) to proxy requests to the Auth.js server configuration. This catch-all route handles all Auth.js API routes.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/guides/configuring-resend.mdx#_snippet_2

LANGUAGE: ts
CODE:
```
export { GET, POST } from "@/auth"
```

----------------------------------------

TITLE: Osu Provider Callback URLs
DESCRIPTION: Configure the callback URL for the Osu provider. This URL is where the OAuth provider will redirect the user after authentication.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/osu.mdx#_snippet_0

LANGUAGE: bash
CODE:
```
https://example.com/api/auth/callback/osu
```

LANGUAGE: bash
CODE:
```
https://example.com/auth/callback/osu
```

LANGUAGE: bash
CODE:
```
https://example.com/auth/callback/osu
```

----------------------------------------

TITLE: Setup Resend Provider in SvelteKit
DESCRIPTION: Configures the Resend provider for SvelteKitAuth.js. This involves importing SvelteKitAuth and the Resend provider, then including Resend in the providers array within the SvelteKitAuth configuration. It also includes a hook to export the handle function.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/authentication/email.mdx#_snippet_9

LANGUAGE: ts
CODE:
```
import SvelteKitAuth from "@auth/sveltekit"
import Resend from "@auth/sveltekit/providers/resend"

export const { handle, signIn, signOut } = SvelteKitAuth({
  providers: [Resend],
})
```

LANGUAGE: ts
CODE:
```
export { handle } from "./auth"
```

----------------------------------------

TITLE: Protect Qwik API Route
DESCRIPTION: Illustrates how to protect a Qwik API route by checking for session data in the `event.sharedMap`. If the session is invalid or expired, it redirects the user.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/session-management/protecting.mdx#_snippet_8

LANGUAGE: ts
CODE:
```
import { RequestHandler } from "./$types"

export const onRequest: RequestHandler = (event) => {
  const session = event.sharedMap.get("session")
  if (!session || new Date(session.expires) < new Date()) {
    throw event.redirect(302, `/`)
  }
}
```

----------------------------------------

TITLE: Configure NextAuth.js with PostgresAdapter (Express)
DESCRIPTION: Shows how to integrate NextAuth.js with the PostgresAdapter in an Express.js application. This example includes setting up the middleware for authentication routes.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/adapters/pg.mdx#_snippet_5

LANGUAGE: ts
CODE:
```
import { ExpressAuth } from "@auth/express"
import PostgresAdapter from "@auth/pg-adapter"
import { Pool } from "pg"

const pool = new Pool({
  host: process.env.DATABASE_HOST,
  user: process.env.DATABASE_USER,
  password: process.env.DATABASE_PASSWORD,
  database: process.env.DATABASE_NAME,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
})

const app = express()

app.set("trust proxy", true)
app.use(
  "/auth/*",
  ExpressAuth({
    providers: [],
    adapter: PostgresAdapter(pool),
  })
)
```

----------------------------------------

TITLE: SvelteKit Page Loading with Session
DESCRIPTION: Provides an example of server-side page loading in SvelteKit, fetching the session and redirecting users to the login page if no valid session is found and they are not already on the login page.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/guides/role-based-access-control.mdx#_snippet_7

LANGUAGE: typescript
CODE:
```
import { redirect, type LoadEvent } from "@sveltejs/kit"
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async (event: LoadEvent) => {
  const session = await event.locals.auth()

  if (!session && event.url.pathname !== "/login") {
    const fromUrl = event.url.pathname + event.url.search
    redirect(307, `/login?redirectTo=${encodeURIComponent(fromUrl)}`)
  }

  return {
    session,
  }
}
```

----------------------------------------

TITLE: Qwik Configuration with Mastodon
DESCRIPTION: Example configuration for Qwik to integrate the Mastodon OAuth provider. This shows how to set up QwikAuth$ with the Mastodon provider for authentication.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/mastodon.mdx#_snippet_3

LANGUAGE: ts
CODE:
```
import { QwikAuth$ } from "@auth/qwik"
import Mastodon from "@auth/qwik/providers/mastodon"

export const {onRequest, useSession, useSignIn, useSignOut } = QwikAuth$(
  () => ({
    providers: [Mastodon],
  })
)
```

----------------------------------------

TITLE: Protect Next.js API Route (App Router)
DESCRIPTION: Demonstrates how to protect an API route in Next.js using the App Router. The `auth` function wraps the route handler, and the authenticated session is available on the request object.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/session-management/protecting.mdx#_snippet_6

LANGUAGE: ts
CODE:
```
import { auth } from "@/auth"
import { NextResponse } from "next/server"

export const GET = auth(function GET(req) {
  if (req.auth) return NextResponse.json(req.auth)
  return NextResponse.json({ message: "Not authenticated" }, { status: 401 })
})
```

----------------------------------------

TITLE: Express Configuration for 42School Provider
DESCRIPTION: Provides an example for setting up the 42School provider in an Express.js application using ExpressAuth. It demonstrates how to use the middleware for authentication routes.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/42-school.mdx#_snippet_5

LANGUAGE: ts
CODE:
```
import { ExpressAuth } from "@auth/express"
import 42School from "@auth/express/providers/42-school"

app.use("/auth/*",
  ExpressAuth({ providers: [ 42School ] })
)
```

----------------------------------------

TITLE: Frontegg Configuration for SvelteKit Auth
DESCRIPTION: Shows the setup for integrating the Frontegg provider with SvelteKit Auth. This example illustrates how to import and use the Frontegg provider within the SvelteKit authentication configuration, requiring corresponding environment variables.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/frontegg.mdx#_snippet_3

LANGUAGE: typescript
CODE:
```
import { SvelteKitAuth } from "@auth/sveltekit"
import Frontegg from "@auth/sveltekit/providers/frontegg"

export const { handle, signIn, signOut } = SvelteKitAuth({
  providers: [Frontegg],
})
```

----------------------------------------

TITLE: Configure Express with Xata Adapter
DESCRIPTION: Sets up an Express.js application to use the Xata Adapter for authentication. It configures the ExpressAuth middleware with the Xata client.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/adapters/xata.mdx#_snippet_6

LANGUAGE: typescript
CODE:
```
import { ExpressAuth } from "@auth/express"
import { XataAdapter } from "@auth/xata-adapter"
import { XataClient } from "../../../xata" // Or wherever you've chosen for the generated client

const client = new XataClient()

const app = express()

app.set("trust proxy", true)
app.use(
  "/auth/*",
  ExpressAuth({
    providers: [],
    adapter: XataAdapter(client),
  })
)
```

----------------------------------------

TITLE: Frontegg Configuration for Express Auth
DESCRIPTION: Provides an example of integrating the Frontegg provider with Express Auth middleware. This snippet demonstrates how to use the ExpressAuth class and include the Frontegg provider in the configuration, typically applied to an authentication route.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/frontegg.mdx#_snippet_4

LANGUAGE: typescript
CODE:
```
import { ExpressAuth } from "@auth/express"
import Frontegg from "@auth/express/providers/frontegg"

app.use("/auth/*", ExpressAuth({ providers: [Frontegg] }))
```

----------------------------------------

TITLE: Freshbooks Callback URLs
DESCRIPTION: Specifies the callback URLs required for Freshbooks OAuth authentication, with variations for different frameworks like Next.js, Qwik, and SvelteKit.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/freshbooks.mdx#_snippet_0

LANGUAGE: bash
CODE:
```
https://example.com/api/auth/callback/freshbooks
```

LANGUAGE: bash
CODE:
```
https://example.com/auth/callback/freshbooks
```

LANGUAGE: bash
CODE:
```
https://example.com/auth/callback/freshbooks
```

----------------------------------------

TITLE: Configure Authentik Callback URL
DESCRIPTION: Specifies the callback URL for the Authentik provider. This URL is used by Authentik to redirect the user back to your application after successful authentication. Ensure this matches the URL configured in your Authentik application settings.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/authentik.mdx#_snippet_0

LANGUAGE: bash
CODE:
```
https://example.com/api/auth/callback/authentik
```

LANGUAGE: bash
CODE:
```
https://example.com/auth/callback/authentik
```

LANGUAGE: bash
CODE:
```
https://example.com/auth/callback/authentik
```

LANGUAGE: bash
CODE:
```
https://example.com/auth/callback/authentik
```

----------------------------------------

TITLE: 42School Provider Callback URLs
DESCRIPTION: Specifies the callback URLs required for the 42School OAuth provider integration. These URLs are used by 42School to redirect users back to your application after authentication.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/42-school.mdx#_snippet_0

LANGUAGE: bash
CODE:
```
https://example.com/api/auth/callback/42-school
```

LANGUAGE: bash
CODE:
```
https://example.com/auth/callback/42-school
```

LANGUAGE: bash
CODE:
```
https://example.com/auth/callback/42-school
```

----------------------------------------

TITLE: Configuring Next.js Middleware with auth()
DESCRIPTION: Illustrates how to integrate the `auth()` function with Next.js Middleware. It can be used as a direct export or as a wrapper for custom middleware logic.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/migrating-to-v5.mdx#_snippet_6

LANGUAGE: diff
CODE:
```
- export { default } from "next-auth/middleware"
+ export { auth as middleware } from "@/auth"
```

LANGUAGE: ts
CODE:
```
import { auth } from "@/auth"

export default auth((req) => {
  // req.auth
})

// Optionally, don't invoke Middleware on some paths
export const config = {
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico).*)"],
}
```

----------------------------------------

TITLE: Default Callback URL Structure
DESCRIPTION: Illustrates the default callback URL structure for Auth.js applications, which is used by OAuth providers to redirect users back after authentication.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/deployment.mdx#_snippet_3

LANGUAGE: javascript
CODE:
```
https://company.com/api/auth/callback/[provider]
```

----------------------------------------

TITLE: Add ForwardEmail Signin Button in Qwik
DESCRIPTION: Implements a sign-in button component for Qwik using the `useSignIn` hook from QwikAuth.js. This component triggers the sign-in process when clicked, redirecting the user upon successful authentication.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/authentication/email.mdx#_snippet_5

LANGUAGE: ts
CODE:
```
import { component$ } from "@builder.io/qwik"
import { useSignIn } from "./plugin@auth"

export default component$(() => {
  const signInSig = useSignIn()

  return (
    <button
      onClick$={() => signInSig.submit({ redirectTo: "/" })}
    >
      SignIn
    </button>
  )
})
```

----------------------------------------

TITLE: Express Configuration with Prisma Adapter
DESCRIPTION: Demonstrates how to integrate the Prisma Adapter with ExpressAuth for Express.js applications. This example sets up the authentication middleware for an Express server.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/adapters/prisma.mdx#_snippet_6

LANGUAGE: ts
CODE:
```
import { ExpressAuth } from "@auth/express"
import { PrismaAdapter } from "@auth/prisma-adapter"
import { prisma } from "@/prisma"

const app = express()

app.set("trust proxy", true)
app.use(
  "/auth/*",
  ExpressAuth({
    providers: [],
    adapter: PrismaAdapter(prisma),
  })
)
```

----------------------------------------

TITLE: Add Mailgun Signin Button
DESCRIPTION: Implement a sign-in button that triggers the Mailgun authentication flow. This typically involves a form that submits the user's email.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/authentication/email.mdx#_snippet_40

LANGUAGE: tsx
CODE:
```
import { signIn } from "../../auth.ts"

export function SignIn() {
  return (
    <form
      action={async (formData) => {
        "use server"
        await signIn("mailgun", formData)
      }}
    >
      <input type="text" name="email" placeholder="Email" />
      <button type="submit">Signin with Mailgun</button>
    </form>
  )
}
```

LANGUAGE: ts
CODE:
```
import { component$ } from "@builder.io/qwik"
import { useSignIn } from "./plugin@auth"

export default component$(() => {
  const signInSig = useSignIn()

  return (
    <button
      onClick$={() => signInSig.submit({ redirectTo: "/" })}
    >
      SignIn
    </button>
  )
})
```

LANGUAGE: html
CODE:
```
<script lang="ts">
  import { SignIn } from "@auth/sveltekit/components"
</script>

<div>
  <nav>
    <img src="/img/logo.svg" alt="Company Logo" />
    <SignIn provider="mailgun" />
  </nav>
</div>
```

----------------------------------------

TITLE: Implement sendVerificationRequest with Resend API (Advanced)
DESCRIPTION: An advanced implementation of `sendVerificationRequest` using the Resend API, supporting HTML and plain text email content, and dynamic theming. It demonstrates fetching API keys from provider configuration.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/guides/configuring-http-email.mdx#_snippet_2

LANGUAGE: ts
CODE:
```
export async function sendVerificationRequest(params) {
  const { identifier: to, provider, url, theme } = params
  const { host } = new URL(url)
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${provider.apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: provider.from,
      to,
      subject: `Sign in to ${host}`,
      html: html({ url, host, theme }),
      text: text({ url, host }),
    }),
  })

  if (!res.ok)
    throw new Error("Resend error: " + JSON.stringify(await res.json()))
}

function html(params: { url: string; host: string; theme: Theme }) {
  const { url, host, theme } = params

  const escapedHost = host.replace(/\./g, "&#8203;.")

  const brandColor = theme.brandColor || "#346df1"
  const color = {
    background: "#f9f9f9",
    text: "#444",
    mainBackground: "#fff",
    buttonBackground: brandColor,
    buttonBorder: brandColor,
    buttonText: theme.buttonText || "#fff",
  }

  return `
<body style="background: ${color.background};">
  <table width="100%" border="0" cellspacing="20" cellpadding="0"
    style="background: ${color.mainBackground}; max-width: 600px; margin: auto; border-radius: 10px;">

```

----------------------------------------

TITLE: Next.js Middleware: Basic Protection
DESCRIPTION: Sets up basic route protection in Next.js using middleware. The `auth` export from NextAuth.js is used as the middleware, protecting all routes by default.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/session-management/protecting.mdx#_snippet_10

LANGUAGE: ts
CODE:
```
export { auth as middleware } from "@/auth"
```

----------------------------------------

TITLE: WordPress Callback URLs
DESCRIPTION: Specifies the callback URLs required for the WordPress OAuth flow. These URLs are used by WordPress to redirect the user back to your application after authentication.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/wordpress.mdx#_snippet_0

LANGUAGE: bash
CODE:
```
https://example.com/api/auth/callback/wordpress
```

LANGUAGE: bash
CODE:
```
https://example.com/auth/callback/wordpress
```

LANGUAGE: bash
CODE:
```
https://example.com/auth/callback/wordpress
```

----------------------------------------

TITLE: Configure Duende Identity Server Provider
DESCRIPTION: Demonstrates how to configure the Duende Identity Server provider within various web frameworks like Next.js, Qwik, SvelteKit, and Express.

SOURCE: https://github.com/nextauthjs/next-auth/blob/main/docs/pages/getting-started/providers/duende-identity-server6.mdx#_snippet_0

LANGUAGE: typescript
CODE:
```
import NextAuth from "next-auth"
import DuendeIdentityServer6 from "next-auth/providers/duende-identity-server6"

export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [
    DuendeIdentityServer6
  ],
})
```

LANGUAGE: typescript
CODE:
```
import { QwikAuth$ } from "@auth/qwik"
import DuendeIdentityServer6 from "@auth/qwik/providers/duende-identity-server6"

export const { onRequest, useSession, useSignIn, useSignOut } = QwikAuth$(() => ({
  providers: [
    DuendeIdentityServer6
  ],
}))
```

LANGUAGE: typescript
CODE:
```
import { SvelteKitAuth } from "@auth/sveltekit"
import DuendeIdentityServer6 from "@auth/sveltekit/providers/duende-identity-server6"

export const { handle, signIn, signOut } = SvelteKitAuth({
  providers: [
    DuendeIdentityServer6
  ],
})
```

LANGUAGE: typescript
CODE:
```
import { ExpressAuth } from "@auth/express"
import DuendeIdentityServer6 from "@auth/express/providers/duende-identity-server6"

app.use("/auth/*", ExpressAuth({ providers: [DuendeIdentityServer6] }))
```