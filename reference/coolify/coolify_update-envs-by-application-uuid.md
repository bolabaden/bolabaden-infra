[Skip to content](https://coolify.io/docs/api-reference/api/operations/update-envs-by-application-uuid#VPContent)

Return to top

# Update Envs (Bulk) [​](https://coolify.io/docs/api-reference/api/operations/update-envs-by-application-uuid\#update-envs-bulk)

PATCH

/applications/{uuid}/envs/bulk

Update multiple envs by application UUID.

## Authorizations [​](https://coolify.io/docs/api-reference/api/operations/update-envs-by-application-uuid\#authorizations)

bearerAuth

Go to `Keys & Tokens` / `API tokens` and create a new token. Use the token as the bearer token.

TypeHTTP (bearer)

## Parameters [​](https://coolify.io/docs/api-reference/api/operations/update-envs-by-application-uuid\#parameters)

### Path Parameters

uuid\*

UUID of the application.

Typestring

Required

format `uuid`

## Request Body [​](https://coolify.io/docs/api-reference/api/operations/update-envs-by-application-uuid\#request-body)

SchemaJSON

JSON

{

"data": \[\
\
{\
\
"key": "string",\
\
"value": "string",\
\
"is\_preview": true,\
\
"is\_build\_time": true,\
\
"is\_literal": true,\
\
"is\_multiline": true,\
\
"is\_shown\_once": true\
\
}\
\
\]

}

## Responses [​](https://coolify.io/docs/api-reference/api/operations/update-envs-by-application-uuid\#responses)

201400401404

Environment variables updated.

Content-Type

application/json

SchemaJSON

JSON

{

"message": "Environment variables updated."

}

PATCH

/applications/{uuid}/envs/bulk

## Playground [​](https://coolify.io/docs/api-reference/api/operations/update-envs-by-application-uuid\#playground)

Authorization

bearerAuth

Variables

Key

Value

uuid\*

Body

JSON

{

data

:

\[\
\
1\
item\
\
0\
\
:\
\
{\
\
key\
\
:\
\
string\
\
value\
\
:\
\
string\
\
is\_preview\
\
:\
\
true\
\
is\_build\_time\
\
:\
\
true\
\
is\_literal\
\
:\
\
true\
\
is\_multiline\
\
:\
\
true\
\
is\_shown\_once\
\
:\
\
true\
\
}\
\
\]

}

Try it out

## Samples [​](https://coolify.io/docs/api-reference/api/operations/update-envs-by-application-uuid\#samples)

BrunocURLJavaScriptPHPPython

Bruno

```
PATCH https://app.coolify.io/api/v1/applications/%7Buuid%7D/envs/bulk

Headers
authorization: Bearer Token
content-type: application/json

Body
{
  "data": [\
    {\
      "key": "string",\
      "value": "string",\
      "is_preview": true,\
      "is_build_time": true,\
      "is_literal": true,\
      "is_multiline": true,\
      "is_shown_once": true\
    }\
  ]
}
```

cURL

```
curl 'https://app.coolify.io/api/v1/applications/%7Buuid%7D/envs/bulk' \
  --request PATCH \
  --header 'Authorization: Bearer Token' \
  --header 'Content-Type: application/json' \
  --data '{
  "data": [\
    {\
      "key": "string",\
      "value": "string",\
      "is_preview": true,\
      "is_build_time": true,\
      "is_literal": true,\
      "is_multiline": true,\
      "is_shown_once": true\
    }\
  ]
}'
```

JavaScript

```
fetch('https://app.coolify.io/api/v1/applications/%7Buuid%7D/envs/bulk', {
  method: 'PATCH',
  headers: {
    Authorization: 'Bearer Token',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    data: [{\
      key: 'string',\
      value: 'string',\
      is_preview: true,\
      is_build_time: true,\
      is_literal: true,\
      is_multiline: true,\
      is_shown_once: true\
    }]
  })
})
```

PHP

```
$ch = curl_init("https://app.coolify.io/api/v1/applications/%7Buuid%7D/envs/bulk");

curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer Token', 'Content-Type: application/json']);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([\
  'data' => [\
    [\
      'key' => 'string',\
      'value' => 'string',\
      'is_preview' => true,\
      'is_build_time' => true,\
      'is_literal' => true,\
      'is_multiline' => true,\
      'is_shown_once' => true\
    ]\
  ]\
]));

curl_exec($ch);

curl_close($ch);
```

Python

```
requests.patch(
    "https://app.coolify.io/api/v1/applications/%7Buuid%7D/envs/bulk",
    headers={
      "Authorization": "Bearer Token",
      "Content-Type": "application/json"
    },
    json={
      "data": [\
        {\
          "key": "string",\
          "value": "string",\
          "is_preview": true,\
          "is_build_time": true,\
          "is_literal": true,\
          "is_multiline": true,\
          "is_shown_once": true\
        }\
      ]
    }
)
```

Powered by [VitePress OpenAPI](https://github.com/enzonotario/vitepress-openapi)

SearchAsk AI

Close

BackupsPostgresqlPrivate NPM registry

[![logo](https://cdn.trieve.ai/favicon.ico)Powered by Trieve](https://trieve.ai/)

![Brand Logo](https://coolify.io/docs/coolify-logo-transparent.png)Ask AI