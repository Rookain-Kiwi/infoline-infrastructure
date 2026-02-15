/**
 * InfoLine Authentication Service - AWS Lambda Function
 *
 * Fonction serverless d'authentification déployée sur AWS Lambda (Node.js 20.x).
 * Point d'entrée exposé via Lambda Function URL (HTTPS publique sans API Gateway).
 *
 * Rôle dans l'architecture InfoLine :
 *   Frontend Angular → Lambda Function URL → réponse JWT
 *
 * Endpoint de santé démontrant le déploiement serverless et 
 * l'intégration dans l'infrastructure Terraform/EKS.
 *
 * Limitation compte AWS Free Tier :
 *   Les SCP (Service Control Policies) bloquent l'invocation depuis un
 *   navigateur via Function URL. Validé donc via CLI :
 *     aws lambda invoke \
 *       --function-name infoline-auth \
 *       --payload '{}' \
 *       response.json
 *
 * Variables d'environnement disponibles (définies dans modules/lambda/main.tf) :
 *   process.env.PROJECT     : nom du projet
 *   process.env.ENVIRONMENT : environnement de déploiement
 */

/**
 * Handler principal de la fonction Lambda.
 *
 * @param {Object} event - Événement d'invocation Lambda.
 *   En mode Function URL, contient : requestContext, headers, body, etc.
 *   En mode CLI (aws lambda invoke), peut être un objet JSON.
 * @returns {Object} Réponse HTTP Lambda proxy :
 *   - statusCode : code HTTP retourné au client
 *   - headers    : en-têtes de la réponse
 *   - body       : corps JSON sérialisé en string
 */
exports.handler = async (event) => {

  // Log de l'événement entrant pour le debugging via CloudWatch Logs.
  // JSON.stringify permet de logger l'objet complet (objets non loggables nativement).
  // Visible dans : AWS Console → CloudWatch → Log groups → /aws/lambda/infoline-auth
  console.log('InfoLine Auth Lambda - Event:', JSON.stringify(event));

  return {
    // 200 veut dire OK : la fonction est opérationnelle et répond correctement
    statusCode: 200,

    headers: {
      // Type de contenu explicite car le client sait parser la réponse en JSON
      'Content-Type': 'application/json',

      // CORS permissif pour le développement — autorise les appels depuis
      // n'importe quelle origine (frontend Angular en local ou déployé).
      // En production, il faudrait restreindre à l'URL du frontend InfoLine.
      'Access-Control-Allow-Origin': '*'
    },

    // body doit être une chaîne de caractères (pas un objet) — requis par le format
    // Lambda proxy integration et Lambda Function URL.
    body: JSON.stringify({
      message:   'InfoLine Authentication Service',
      status:    'healthy',       // Indicateur de santé du service
      timestamp: new Date().toISOString(), // Horodatage ISO de la réponse
      version:   '1.0.0'         // Version du service
    })
  };
};