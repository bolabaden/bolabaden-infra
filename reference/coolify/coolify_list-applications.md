[Skip to content](https://coolify.io/docs/api-reference/api/operations/list-applications#VPContent)

Return to top

# List [​](https://coolify.io/docs/api-reference/api/operations/list-applications\#list)

GET

/applications

List all applications.

## Authorizations [​](https://coolify.io/docs/api-reference/api/operations/list-applications\#authorizations)

bearerAuth

Go to `Keys & Tokens` / `API tokens` and create a new token. Use the token as the bearer token.

TypeHTTP (bearer)

## Responses [​](https://coolify.io/docs/api-reference/api/operations/list-applications\#responses)

200400401

Get all applications.

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
"description": "string",\
\
"repository\_project\_id": 0,\
\
"uuid": "string",\
\
"name": "string",\
\
"fqdn": "string",\
\
"config\_hash": "string",\
\
"git\_repository": "string",\
\
"git\_branch": "string",\
\
"git\_commit\_sha": "string",\
\
"git\_full\_url": "string",\
\
"docker\_registry\_image\_name": "string",\
\
"docker\_registry\_image\_tag": "string",\
\
"build\_pack": "string",\
\
"static\_image": "string",\
\
"install\_command": "string",\
\
"build\_command": "string",\
\
"start\_command": "string",\
\
"ports\_exposes": "string",\
\
"ports\_mappings": "string",\
\
"custom\_network\_aliases": "string",\
\
"base\_directory": "string",\
\
"publish\_directory": "string",\
\
"health\_check\_enabled": true,\
\
"health\_check\_path": "string",\
\
"health\_check\_port": "string",\
\
"health\_check\_host": "string",\
\
"health\_check\_method": "string",\
\
"health\_check\_return\_code": 0,\
\
"health\_check\_scheme": "string",\
\
"health\_check\_response\_text": "string",\
\
"health\_check\_interval": 0,\
\
"health\_check\_timeout": 0,\
\
"health\_check\_retries": 0,\
\
"health\_check\_start\_period": 0,\
\
"limits\_memory": "string",\
\
"limits\_memory\_swap": "string",\
\
"limits\_memory\_swappiness": 0,\
\
"limits\_memory\_reservation": "string",\
\
"limits\_cpus": "string",\
\
"limits\_cpuset": "string",\
\
"limits\_cpu\_shares": 0,\
\
"status": "string",\
\
"preview\_url\_template": "string",\
\
"destination\_type": "string",\
\
"destination\_id": 0,\
\
"source\_id": 0,\
\
"private\_key\_id": 0,\
\
"environment\_id": 0,\
\
"dockerfile": "string",\
\
"dockerfile\_location": "string",\
\
"custom\_labels": "string",\
\
"dockerfile\_target\_build": "string",\
\
"manual\_webhook\_secret\_github": "string",\
\
"manual\_webhook\_secret\_gitlab": "string",\
\
"manual\_webhook\_secret\_bitbucket": "string",\
\
"manual\_webhook\_secret\_gitea": "string",\
\
"docker\_compose\_location": "string",\
\
"docker\_compose": "string",\
\
"docker\_compose\_raw": "string",\
\
"docker\_compose\_domains": "string",\
\
"docker\_compose\_custom\_start\_command": "string",\
\
"docker\_compose\_custom\_build\_command": "string",\
\
"swarm\_replicas": 0,\
\
"swarm\_placement\_constraints": "string",\
\
"custom\_docker\_run\_options": "string",\
\
"post\_deployment\_command": "string",\
\
"post\_deployment\_command\_container": "string",\
\
"pre\_deployment\_command": "string",\
\
"pre\_deployment\_command\_container": "string",\
\
"watch\_paths": "string",\
\
"custom\_healthcheck\_found": true,\
\
"redirect": "string",\
\
"created\_at": "string",\
\
"updated\_at": "string",\
\
"deleted\_at": "string",\
\
"compose\_parsing\_version": "string",\
\
"custom\_nginx\_configuration": "string",\
\
"is\_http\_basic\_auth\_enabled": true,\
\
"http\_basic\_auth\_username": "string",\
\
"http\_basic\_auth\_password": "string"\
\
}\
\
\]

GET

/applications

## Playground [​](https://coolify.io/docs/api-reference/api/operations/list-applications\#playground)

Authorization

bearerAuth

Try it out

## Samples [​](https://coolify.io/docs/api-reference/api/operations/list-applications\#samples)

BrunocURLJavaScriptPHPPython

Bruno

```
GET https://app.coolify.io/api/v1/applications

Headers
authorization: Bearer Token

```

cURL

```
curl https://app.coolify.io/api/v1/applications \
  --header 'Authorization: Bearer Token'
```

JavaScript

```
fetch('https://app.coolify.io/api/v1/applications', {
  headers: {
    Authorization: 'Bearer Token'
  }
})
```

PHP

```
$ch = curl_init("https://app.coolify.io/api/v1/applications");

curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer Token']);

curl_exec($ch);

curl_close($ch);
```

Python

```
requests.get(
    "https://app.coolify.io/api/v1/applications",
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