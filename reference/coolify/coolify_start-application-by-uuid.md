[Skip to content](https://coolify.io/docs/api-reference/api/operations/start-application-by-uuid#VPContent)

Return to top

# Start [​](https://coolify.io/docs/api-reference/api/operations/start-application-by-uuid\#start)

GET

/applications/{uuid}/start

Start application. `Post` request is also accepted.

## Authorizations [​](https://coolify.io/docs/api-reference/api/operations/start-application-by-uuid\#authorizations)

bearerAuth

Go to `Keys & Tokens` / `API tokens` and create a new token. Use the token as the bearer token.

TypeHTTP (bearer)

## Parameters [​](https://coolify.io/docs/api-reference/api/operations/start-application-by-uuid\#parameters)

### Path Parameters

uuid\*

UUID of the application.

Typestring

Required

format `uuid`

### Query Parameters

force

Force rebuild.

Typeboolean

default `false`

instant\_deploy

Instant deploy (skip queuing).

Typeboolean

default `false`

## Responses [​](https://coolify.io/docs/api-reference/api/operations/start-application-by-uuid\#responses)

200400401404

Start application.

Content-Type

application/json

SchemaJSON

JSON

{

"message": "Deployment request queued.",

"deployment\_uuid": "doogksw"

}

GET

/applications/{uuid}/start

## Playground [​](https://coolify.io/docs/api-reference/api/operations/start-application-by-uuid\#playground)

Authorization

bearerAuth

Variables

Key

Value

uuid\*

force

instant\_deploy

Try it out

## Samples [​](https://coolify.io/docs/api-reference/api/operations/start-application-by-uuid\#samples)

BrunocURLJavaScriptPHPPython

Bruno

```
GET https://app.coolify.io/api/v1/applications/%7Buuid%7D/start

Headers
authorization: Bearer Token

```

cURL

```
curl 'https://app.coolify.io/api/v1/applications/%7Buuid%7D/start' \
  --header 'Authorization: Bearer Token'
```

JavaScript

```
fetch('https://app.coolify.io/api/v1/applications/%7Buuid%7D/start', {
  headers: {
    Authorization: 'Bearer Token'
  }
})
```

PHP

```
$ch = curl_init("https://app.coolify.io/api/v1/applications/%7Buuid%7D/start");

curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer Token']);

curl_exec($ch);

curl_close($ch);
```

Python

```
requests.get(
    "https://app.coolify.io/api/v1/applications/%7Buuid%7D/start",
    headers={
      "Authorization": "Bearer Token"
    }
)
```

Powered by [VitePress OpenAPI](https://github.com/enzonotario/vitepress-openapi)

SearchAsk AI

Close

Loading...

[![logo](https://cdn.trieve.ai/favicon.ico)Powered by Trieve](https://trieve.ai/)

![Brand Logo](https://coolify.io/docs/coolify-logo-transparent.png)Ask AI