[Skip to content](https://coolify.io/docs/api-reference/api/operations/create-dockercompose-application#VPContent)

Return to top

# Create (Docker Compose) [​](https://coolify.io/docs/api-reference/api/operations/create-dockercompose-application\#create-docker-compose)

POST

/applications/dockercompose

Create new application based on a docker-compose file.

## Authorizations [​](https://coolify.io/docs/api-reference/api/operations/create-dockercompose-application\#authorizations)

bearerAuth

Go to `Keys & Tokens` / `API tokens` and create a new token. Use the token as the bearer token.

TypeHTTP (bearer)

## Request Body [​](https://coolify.io/docs/api-reference/api/operations/create-dockercompose-application\#request-body)

SchemaJSON

JSON

{

"project\_uuid": "string",

"server\_uuid": "string",

"environment\_name": "string",

"environment\_uuid": "string",

"docker\_compose\_raw": "string",

"destination\_uuid": "string",

"name": "string",

"description": "string",

"instant\_deploy": true,

"use\_build\_server": true,

"connect\_to\_docker\_network": true

}

## Responses [​](https://coolify.io/docs/api-reference/api/operations/create-dockercompose-application\#responses)

201400401

Application created successfully.

Content-Type

application/json

SchemaJSON

JSON

{

"uuid": "string"

}

POST

/applications/dockercompose

## Playground [​](https://coolify.io/docs/api-reference/api/operations/create-dockercompose-application\#playground)

Authorization

bearerAuth

Body

JSON

{

project\_uuid

:

string

server\_uuid

:

string

environment\_name

:

string

environment\_uuid

:

string

docker\_compose\_raw

:

string

destination\_uuid

:

string

name

:

string

description

:

string

instant\_deploy

:

true

use\_build\_server

:

true

connect\_to\_docker\_network

:

true

}

Try it out

## Samples [​](https://coolify.io/docs/api-reference/api/operations/create-dockercompose-application\#samples)

BrunocURLJavaScriptPHPPython

Bruno

```
POST https://app.coolify.io/api/v1/applications/dockercompose

Headers
authorization: Bearer Token
content-type: application/json

Body
{
  "project_uuid": "string",
  "server_uuid": "string",
  "environment_name": "string",
  "environment_uuid": "string",
  "docker_compose_raw": "string",
  "destination_uuid": "string",
  "name": "string",
  "description": "string",
  "instant_deploy": true,
  "use_build_server": true,
  "connect_to_docker_network": true
}
```

cURL

```
curl https://app.coolify.io/api/v1/applications/dockercompose \
  --request POST \
  --header 'Authorization: Bearer Token' \
  --header 'Content-Type: application/json' \
  --data '{
  "project_uuid": "string",
  "server_uuid": "string",
  "environment_name": "string",
  "environment_uuid": "string",
  "docker_compose_raw": "string",
  "destination_uuid": "string",
  "name": "string",
  "description": "string",
  "instant_deploy": true,
  "use_build_server": true,
  "connect_to_docker_network": true
}'
```

JavaScript

```
fetch('https://app.coolify.io/api/v1/applications/dockercompose', {
  method: 'POST',
  headers: {
    Authorization: 'Bearer Token',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    project_uuid: 'string',
    server_uuid: 'string',
    environment_name: 'string',
    environment_uuid: 'string',
    docker_compose_raw: 'string',
    destination_uuid: 'string',
    name: 'string',
    description: 'string',
    instant_deploy: true,
    use_build_server: true,
    connect_to_docker_network: true
  })
})
```

PHP

```
$ch = curl_init("https://app.coolify.io/api/v1/applications/dockercompose");

curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer Token', 'Content-Type: application/json']);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([\
  'project_uuid' => 'string',\
  'server_uuid' => 'string',\
  'environment_name' => 'string',\
  'environment_uuid' => 'string',\
  'docker_compose_raw' => 'string',\
  'destination_uuid' => 'string',\
  'name' => 'string',\
  'description' => 'string',\
  'instant_deploy' => true,\
  'use_build_server' => true,\
  'connect_to_docker_network' => true\
]));

curl_exec($ch);

curl_close($ch);
```

Python

```
requests.post(
    "https://app.coolify.io/api/v1/applications/dockercompose",
    headers={
      "Authorization": "Bearer Token",
      "Content-Type": "application/json"
    },
    json={
      "project_uuid": "string",
      "server_uuid": "string",
      "environment_name": "string",
      "environment_uuid": "string",
      "docker_compose_raw": "string",
      "destination_uuid": "string",
      "name": "string",
      "description": "string",
      "instant_deploy": true,
      "use_build_server": true,
      "connect_to_docker_network": true
    }
)
```

Powered by [VitePress OpenAPI](https://github.com/enzonotario/vitepress-openapi)

SearchAsk AI

Close

BackupsPostgresqlPrivate NPM registry

[![logo](https://cdn.trieve.ai/favicon.ico)Powered by Trieve](https://trieve.ai/)

![Brand Logo](https://coolify.io/docs/coolify-logo-transparent.png)Ask AI