[Skip to content](https://coolify.io/docs/api-reference/api/operations/list-services#VPContent)

Return to top

# List [​](https://coolify.io/docs/api-reference/api/operations/list-services\#list)

GET

/services

List all services.

## Authorizations [​](https://coolify.io/docs/api-reference/api/operations/list-services\#authorizations)

bearerAuth

Go to `Keys & Tokens` / `API tokens` and create a new token. Use the token as the bearer token.

TypeHTTP (bearer)

## Responses [​](https://coolify.io/docs/api-reference/api/operations/list-services\#responses)

200400401

Get all services

Content-Type

application/json

SchemaJSON

JSON

\[\
\
{\
\
"id": 0,\
\
"uuid": "string",\
\
"name": "string",\
\
"environment\_id": 0,\
\
"server\_id": 0,\
\
"description": "string",\
\
"docker\_compose\_raw": "string",\
\
"docker\_compose": "string",\
\
"destination\_type": "string",\
\
"destination\_id": 0,\
\
"connect\_to\_docker\_network": true,\
\
"is\_container\_label\_escape\_enabled": true,\
\
"is\_container\_label\_readonly\_enabled": true,\
\
"config\_hash": "string",\
\
"service\_type": "string",\
\
"created\_at": "string",\
\
"updated\_at": "string",\
\
"deleted\_at": "string"\
\
}\
\
\]

GET

/services

## Playground [​](https://coolify.io/docs/api-reference/api/operations/list-services\#playground)

Authorization

bearerAuth

Try it out

## Samples [​](https://coolify.io/docs/api-reference/api/operations/list-services\#samples)

BrunocURLJavaScriptPHPPython

Bruno

```
GET https://app.coolify.io/api/v1/services

Headers
authorization: Bearer Token

```

cURL

```
curl https://app.coolify.io/api/v1/services \
  --header 'Authorization: Bearer Token'
```

JavaScript

```
fetch('https://app.coolify.io/api/v1/services', {
  headers: {
    Authorization: 'Bearer Token'
  }
})
```

PHP

```
$ch = curl_init("https://app.coolify.io/api/v1/services");

curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer Token']);

curl_exec($ch);

curl_close($ch);
```

Python

```
requests.get("https://app.coolify.io/api/v1/services",
    headers={
      "Authorization": "Bearer Token"
    }
)
```

Powered by [VitePress OpenAPI](https://github.com/enzonotario/vitepress-openapi)

SearchAsk AI

Close

BackupsPostgresqlPrivate NPM registry

[![logo](https://cdn.trieve.ai/favicon.ico)Powered by Trieve](https://trieve.ai/)

![Brand Logo](https://coolify.io/docs/coolify-logo-transparent.png)Ask AI