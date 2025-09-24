[Skip to content](https://coolify.io/docs/api-reference/api/operations/create-service#VPContent)

Return to top

# Create service [​](https://coolify.io/docs/api-reference/api/operations/create-service\#create-service)

POST

/services

Create a one-click / custom service

## Authorizations [​](https://coolify.io/docs/api-reference/api/operations/create-service\#authorizations)

bearerAuth

Go to `Keys & Tokens` / `API tokens` and create a new token. Use the token as the bearer token.

TypeHTTP (bearer)

## Request Body [​](https://coolify.io/docs/api-reference/api/operations/create-service\#request-body)

SchemaJSON

JSON

{

"type": "string",

"name": "string",

"description": "string",

"project\_uuid": "string",

"environment\_name": "string",

"environment\_uuid": "string",

"server\_uuid": "string",

"destination\_uuid": "string",

"instant\_deploy": false,

"docker\_compose\_raw": "string"

}

## Responses [​](https://coolify.io/docs/api-reference/api/operations/create-service\#responses)

201400401

Service created successfully.

Content-Type

application/json

SchemaJSON

JSON

{

"uuid": "string",

"domains": \[\
\
"string"\
\
\]

}

POST

/services

## Playground [​](https://coolify.io/docs/api-reference/api/operations/create-service\#playground)

Authorization

bearerAuth

Body

JSON

{

type

:

string

name

:

string

description

:

string

project\_uuid

:

string

environment\_name

:

string

environment\_uuid

:

string

server\_uuid

:

string

destination\_uuid

:

string

instant\_deploy

:

false

docker\_compose\_raw

:

string

}

Try it out

## Samples [​](https://coolify.io/docs/api-reference/api/operations/create-service\#samples)

BrunocURLJavaScriptPHPPython

Bruno

```
POST https://app.coolify.io/api/v1/services

Headers
authorization: Bearer Token
content-type: application/json

Body
{
  "type": "string",
  "name": "string",
  "description": "string",
  "project_uuid": "string",
  "environment_name": "string",
  "environment_uuid": "string",
  "server_uuid": "string",
  "destination_uuid": "string",
  "instant_deploy": false,
  "docker_compose_raw": "string"
}
```

cURL

```
curl https://app.coolify.io/api/v1/services \
  --request POST \
  --header 'Authorization: Bearer Token' \
  --header 'Content-Type: application/json' \
  --data '{
  "type": "string",
  "name": "string",
  "description": "string",
  "project_uuid": "string",
  "environment_name": "string",
  "environment_uuid": "string",
  "server_uuid": "string",
  "destination_uuid": "string",
  "instant_deploy": false,
  "docker_compose_raw": "string"
}'
```

JavaScript

```
fetch('https://app.coolify.io/api/v1/services', {
  method: 'POST',
  headers: {
    Authorization: 'Bearer Token',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    type: 'string',
    name: 'string',
    description: 'string',
    project_uuid: 'string',
    environment_name: 'string',
    environment_uuid: 'string',
    server_uuid: 'string',
    destination_uuid: 'string',
    instant_deploy: false,
    docker_compose_raw: 'string'
  })
})
```

PHP

```
$ch = curl_init("https://app.coolify.io/api/v1/services");

curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer Token', 'Content-Type: application/json']);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([\
  'type' => 'string',\
  'name' => 'string',\
  'description' => 'string',\
  'project_uuid' => 'string',\
  'environment_name' => 'string',\
  'environment_uuid' => 'string',\
  'server_uuid' => 'string',\
  'destination_uuid' => 'string',\
  'instant_deploy' => false,\
  'docker_compose_raw' => 'string'\
]));

curl_exec($ch);

curl_close($ch);
```

Python

```
requests.post("https://app.coolify.io/api/v1/services",
    headers={
      "Authorization": "Bearer Token",
      "Content-Type": "application/json"
    },
    json={
      "type": "string",
      "name": "string",
      "description": "string",
      "project_uuid": "string",
      "environment_name": "string",
      "environment_uuid": "string",
      "server_uuid": "string",
      "destination_uuid": "string",
      "instant_deploy": false,
      "docker_compose_raw": "string"
    }
)
```

Powered by [VitePress OpenAPI](https://github.com/enzonotario/vitepress-openapi)

SearchAsk AI

Close

BackupsPostgresqlPrivate NPM registry

[![logo](https://cdn.trieve.ai/favicon.ico)Powered by Trieve](https://trieve.ai/)

![Brand Logo](https://coolify.io/docs/coolify-logo-transparent.png)Ask AI