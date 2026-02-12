exports.handler = async (event) => {
    console.log('InfoLine Auth Lambda - Event:', JSON.stringify(event));

    return {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({
            message: 'InfoLine Authentication Service',
            status: 'healthy',
            timestamp: new Date().toISOString(),
            version: '1.0.0'
        })
    };
};
