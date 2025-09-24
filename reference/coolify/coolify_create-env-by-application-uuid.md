[Skip to content](https://coolify.io/docs/api-reference/api/operations/create-env-by-application-uuid#VPContent)

Return to top

# Create Env [​](https://coolify.io/docs/api-reference/api/operations/create-env-by-application-uuid\#create-env)

POST

/applications/{uuid}/envs

Create env by application UUID.

## Authorizations [​](https://coolify.io/docs/api-reference/api/operations/create-env-by-application-uuid\#authorizations)

bearerAuth

Go to `Keys & Tokens` / `API tokens` and create a new token. Use the token as the bearer token.

TypeHTTP (bearer)

## Parameters [​](https://coolify.io/docs/api-reference/api/operations/create-env-by-application-uuid\#parameters)

### Path Parameters

uuid\*

UUID of the application.

Typestring

Required

format `uuid`

## Request Body [​](https://coolify.io/docs/api-reference/api/operations/create-env-by-application-uuid\#request-body)

SchemaJSON

JSON

{

"key": "string",

"value": "string",

"is\_preview": true,

"is\_build\_time": true,

"is\_literal": true,

"is\_multiline": true,

"is\_shown\_once": true

}

## Responses [​](https://coolify.io/docs/api-reference/api/operations/create-env-by-application-uuid\#responses)

201400401404

Environment variable created.

Content-Type

application/json

SchemaJSON

JSON

{

"uuid": "nc0k04gk8g0cgsk440g0koko"

}

POST

/applications/{uuid}/envs

## Playground [​](https://coolify.io/docs/api-reference/api/operations/create-env-by-application-uuid\#playground)

Authorization

bearerAuth

Variables

Key

Value

uuid\*

Body

JSON

{

key

:

string

value

:

string

is\_preview

:

true

is\_build\_time

:

true

is\_literal

:

true

is\_multiline

:

true

is\_shown\_once

:

true

}

Try it out

## Samples [​](https://coolify.io/docs/api-reference/api/operations/create-env-by-application-uuid\#samples)

BrunocURLJavaScriptPHPPython

Bruno

```
POST https://app.coolify.io/api/v1/applications/%7Buuid%7D/envs

Headers
authorization: Bearer Token
content-type: application/json

Body
{
  "key": "string",
  "value": "string",
  "is_preview": true,
  "is_build_time": true,
  "is_literal": true,
  "is_multiline": true,
  "is_shown_once": true
}
```

cURL

```
curl 'https://app.coolify.io/api/v1/applications/%7Buuid%7D/envs' \
  --request POST \
  --header 'Authorization: Bearer Token' \
  --header 'Content-Type: application/json' \
  --data '{
  "key": "string",
  "value": "string",
  "is_preview": true,
  "is_build_time": true,
  "is_literal": true,
  "is_multiline": true,
  "is_shown_once": true
}'
```

JavaScript

```
fetch('https://app.coolify.io/api/v1/applications/%7Buuid%7D/envs', {
  method: 'POST',
  headers: {
    Authorization: 'Bearer Token',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    key: 'string',
    value: 'string',
    is_preview: true,
    is_build_time: true,
    is_literal: true,
    is_multiline: true,
    is_shown_once: true
  })
})
```

PHP

```
$ch = curl_init("https://app.coolify.io/api/v1/applications/%7Buuid%7D/envs");

curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer Token', 'Content-Type: application/json']);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([\
  'key' => 'string',\
  'value' => 'string',\
  'is_preview' => true,\
  'is_build_time' => true,\
  'is_literal' => true,\
  'is_multiline' => true,\
  'is_shown_once' => true\
]));

curl_exec($ch);

curl_close($ch);
```

Python

```
requests.post(
    "https://app.coolify.io/api/v1/applications/%7Buuid%7D/envs",
    headers={
      "Authorization": "Bearer Token",
      "Content-Type": "application/json"
    },
    json={
      "key": "string",
      "value": "string",
      "is_preview": true,
      "is_build_time": true,
      "is_literal": true,
      "is_multiline": true,
      "is_shown_once": true
    }
)
```

Powered by [VitePress OpenAPI](https://github.com/enzonotario/vitepress-openapi)

SearchAsk AI

Close

BackupsPostgresqlPrivate NPM registry

[![logo](https://cdn.trieve.ai/favicon.ico)Powered by Trieve](https://trieve.ai/)

![Brand Logo](https://coolify.io/docs/coolify-logo-transparent.png)Ask AI