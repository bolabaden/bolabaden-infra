[Skip to content](https://coolify.io/docs/api-reference/api/operations/start-service-by-uuid#VPContent)

Return to top

# Start [​](https://coolify.io/docs/api-reference/api/operations/start-service-by-uuid\#start)

GET

/services/{uuid}/start

Start service. `Post` request is also accepted.

## Authorizations [​](https://coolify.io/docs/api-reference/api/operations/start-service-by-uuid\#authorizations)

bearerAuth

Go to `Keys & Tokens` / `API tokens` and create a new token. Use the token as the bearer token.

TypeHTTP (bearer)

## Parameters [​](https://coolify.io/docs/api-reference/api/operations/start-service-by-uuid\#parameters)

### Path Parameters

uuid\*

UUID of the service.

Typestring

Required

format `uuid`

## Responses [​](https://coolify.io/docs/api-reference/api/operations/start-service-by-uuid\#responses)

200400401404

Start service.

Content-Type

application/json

SchemaJSON

JSON

{

"message": "Service starting request queued."

}

GET

/services/{uuid}/start

## Playground [​](https://coolify.io/docs/api-reference/api/operations/start-service-by-uuid\#playground)

Authorization

bearerAuth

Variables

Key

Value

uuid\*

Try it out

## Samples [​](https://coolify.io/docs/api-reference/api/operations/start-service-by-uuid\#samples)

BrunocURLJavaScriptPHPPython

Bruno

```
GET https://app.coolify.io/api/v1/services/%7Buuid%7D/start

Headers
authorization: Bearer Token

```

cURL

```
curl 'https://app.coolify.io/api/v1/services/%7Buuid%7D/start' \
  --header 'Authorization: Bearer Token'
```

JavaScript

```
fetch('https://app.coolify.io/api/v1/services/%7Buuid%7D/start', {
  headers: {
    Authorization: 'Bearer Token'
  }
})
```

PHP

```
$ch = curl_init("https://app.coolify.io/api/v1/services/%7Buuid%7D/start");

curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer Token']);

curl_exec($ch);

curl_close($ch);
```

Python

```
requests.get(
    "https://app.coolify.io/api/v1/services/%7Buuid%7D/start",
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

![Brand Logo](https://coolify.io/docs/coolify-logo-transparent.png)Ask AI[Skip to content](https://coolify.io/docs/api-reference/api/operations/start-service-by-uuid#VPContent)

Return to top

# Start [​](https://coolify.io/docs/api-reference/api/operations/start-service-by-uuid\#start)

GET

/services/{uuid}/start

Start service. `Post` request is also accepted.

## Authorizations [​](https://coolify.io/docs/api-reference/api/operations/start-service-by-uuid\#authorizations)

bearerAuth

Go to `Keys & Tokens` / `API tokens` and create a new token. Use the token as the bearer token.

TypeHTTP (bearer)

## Parameters [​](https://coolify.io/docs/api-reference/api/operations/start-service-by-uuid\#parameters)

### Path Parameters

uuid\*

UUID of the service.

Typestring

Required

format `uuid`

## Responses [​](https://coolify.io/docs/api-reference/api/operations/start-service-by-uuid\#responses)

200400401404

Start service.

Content-Type

application/json

SchemaJSON

JSON

{

"message": "Service starting request queued."

}

GET

/services/{uuid}/start

## Playground [​](https://coolify.io/docs/api-reference/api/operations/start-service-by-uuid\#playground)

Authorization

bearerAuth

Variables

Key

Value

uuid\*

Try it out

## Samples [​](https://coolify.io/docs/api-reference/api/operations/start-service-by-uuid\#samples)

BrunocURLJavaScriptPHPPython

Bruno

```
GET https://app.coolify.io/api/v1/services/%7Buuid%7D/start

Headers
authorization: Bearer Token

```

cURL

```
curl 'https://app.coolify.io/api/v1/services/%7Buuid%7D/start' \
  --header 'Authorization: Bearer Token'
```

JavaScript

```
fetch('https://app.coolify.io/api/v1/services/%7Buuid%7D/start', {
  headers: {
    Authorization: 'Bearer Token'
  }
})
```

PHP

```
$ch = curl_init("https://app.coolify.io/api/v1/services/%7Buuid%7D/start");

curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer Token']);

curl_exec($ch);

curl_close($ch);
```

Python

```
requests.get(
    "https://app.coolify.io/api/v1/services/%7Buuid%7D/start",
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