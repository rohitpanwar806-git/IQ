import json
import boto3
import os
from datetime import datetime
from decimal import Decimal

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')

# Get table names from environment
USERS_TABLE = os.environ.get('USERS_TABLE')
SCORES_TABLE = os.environ.get('SCORES_TABLE')
LEADERBOARDS_TABLE = os.environ.get('LEADERBOARDS_TABLE')
ASSETS_BUCKET = os.environ.get('ASSETS_BUCKET')

# Get DynamoDB tables
users_table = dynamodb.Table(USERS_TABLE)
scores_table = dynamodb.Table(SCORES_TABLE)
leaderboards_table = dynamodb.Table(LEADERBOARDS_TABLE)

def handler(event, context):
    """
    Main Lambda handler for leaderboard API
    Routes requests to appropriate handlers
    """
    try:
        http_method = event.get('requestContext', {}).get('http', {}).get('method')
        path = event.get('rawPath')
        
        # CORS preflight
        if http_method == 'OPTIONS':
            return cors_response(200, {'message': 'OK'})
        
        # Route requests
        if 'leaderboard' in path:
            if http_method == 'GET':
                return get_leaderboard(event)
            elif http_method == 'POST':
                return post_score(event)
        
        elif 'users' in path:
            if http_method == 'GET':
                return get_user_profile(event)
            elif http_method == 'POST':
                return create_user(event)
        
        return error_response(404, 'Route not found')
    
    except Exception as e:
        print(f'Error: {str(e)}')
        return error_response(500, str(e))

def get_leaderboard(event):
    """Get top scores for a game"""
    try:
        params = event.get('queryStringParameters', {})
        game_id = params.get('gameId')
        limit = int(params.get('limit', 100))
        
        if not game_id:
            return error_response(400, 'gameId is required')
        
        # Query leaderboard table
        response = leaderboards_table.query(
            KeyConditionExpression='gameId = :gameId',
            ExpressionAttributeValues={':gameId': game_id},
            ScanIndexForward=False,  # Descending order (highest scores first)
            Limit=limit
        )
        
        leaderboard = []
        for item in response.get('Items', []):
            leaderboard.append({
                'rank': len(leaderboard) + 1,
                'userId': item.get('userId'),
                'score': int(item.get('score', 0)),
                'displayName': item.get('displayName', 'Anonymous'),
                'timestamp': int(item.get('timestamp', 0))
            })
        
        return success_response({
            'gameId': game_id,
            'leaderboard': leaderboard,
            'count': len(leaderboard)
        })
    
    except Exception as e:
        print(f'Error in get_leaderboard: {str(e)}')
        return error_response(500, str(e))

def post_score(event):
    """Submit a game score"""
    try:
        body = json.loads(event.get('body', '{}'))
        
        # Validate required fields
        required = ['userId', 'gameId', 'score', 'displayName']
        for field in required:
            if field not in body:
                return error_response(400, f'{field} is required')
        
        user_id = body['userId']
        game_id = body['gameId']
        score = int(body['score'])
        display_name = body['displayName']
        timestamp = int(datetime.now().timestamp() * 1000)
        
        # Save to scores table
        scores_table.put_item(
            Item={
                'userId': user_id,
                'timestamp': timestamp,
                'gameId': game_id,
                'score': score,
                'displayName': display_name,
                'duration': int(body.get('duration', 0)),
                'difficulty': body.get('difficulty', 'normal')
            }
        )
        
        # Update leaderboard table
        leaderboards_table.put_item(
            Item={
                'gameId': game_id,
                'score': Decimal(str(score)),  # Use Decimal for proper sorting
                'userId': user_id,
                'displayName': display_name,
                'timestamp': timestamp
            }
        )
        
        return success_response({
            'message': 'Score submitted successfully',
            'userId': user_id,
            'gameId': game_id,
            'score': score
        })
    
    except Exception as e:
        print(f'Error in post_score: {str(e)}')
        return error_response(500, str(e))

def get_user_profile(event):
    """Get user profile"""
    try:
        params = event.get('queryStringParameters', {})
        user_id = params.get('userId')
        
        if not user_id:
            return error_response(400, 'userId is required')
        
        response = users_table.get_item(Key={'userId': user_id})
        user = response.get('Item')
        
        if not user:
            return error_response(404, 'User not found')
        
        return success_response(user)
    
    except Exception as e:
        print(f'Error in get_user_profile: {str(e)}')
        return error_response(500, str(e))

def create_user(event):
    """Create user profile"""
    try:
        body = json.loads(event.get('body', '{}'))
        
        user_id = body.get('userId')
        display_name = body.get('displayName', 'Anonymous')
        
        if not user_id:
            return error_response(400, 'userId is required')
        
        users_table.put_item(
            Item={
                'userId': user_id,
                'displayName': display_name,
                'totalScore': 0,
                'gamesPlayed': 0,
                'createdAt': int(datetime.now().timestamp() * 1000)
            }
        )
        
        return success_response({
            'message': 'User created successfully',
            'userId': user_id
        })
    
    except Exception as e:
        print(f'Error in create_user: {str(e)}')
        return error_response(500, str(e))

def success_response(data, status_code=200):
    """Return successful response"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(data)
    }

def error_response(status_code, message):
    """Return error response"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({'error': message})
    }

def cors_response(status_code, data):
    """Return CORS preflight response"""
    return {
        'statusCode': status_code,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': '*'
        },
        'body': json.dumps(data)
    }
