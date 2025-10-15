import base64
import boto3
import json
import os
from boto3.dynamodb.types import TypeSerializer
from botocore.client import Config

region = os.environ.get('REGION')
environment = os.environ.get('ENVIRONMENT')
central_account_id = os.environ.get('CENTRAL_ACCOUNT_ID')
notification_topic_arn = os.environ.get('NOTIFICATION_TOPIC_ARN')
dynamodb_arn_prefix = f'arn:aws:dynamodb:{region}:{central_account_id}:table/'

tables = {
    'events': os.environ.get('DYNAMODB_EVENTS_TABLE_NAME'),
    'modules': os.environ.get('DYNAMODB_MODULES_TABLE_NAME'),
    'policies': os.environ.get('DYNAMODB_POLICIES_TABLE_NAME'),
    'deployments': os.environ.get('DYNAMODB_DEPLOYMENTS_TABLE_NAME'),
    'change_records': os.environ.get('DYNAMODB_CHANGE_RECORDS_TABLE_NAME')
}

ecs_cluster_name = os.environ.get('ECS_CLUSTER_NAME')
ecs_task_definition = os.environ.get('ECS_TASK_DEFINITION')

buckets = {
    'modules': os.environ.get('MODULE_S3_BUCKET'),
    'policies': os.environ.get('POLICY_S3_BUCKET'),
    'change_records': os.environ.get('CHANGE_RECORD_S3_BUCKET'),
    'providers': os.environ.get('PROVIDERS_S3_BUCKET'),
}
    
def insert_db(event):
    dynamodb = boto3.resource('dynamodb')
    dynamodb_table = dynamodb_arn_prefix + tables[event.get('table')]
    dynamodb_row = event.get('data')
    table = dynamodb.Table(dynamodb_table)
    response_dict = table.put_item(Item=dynamodb_row)
    return response_dict

def transact_write(event):
    transact_items = []    
    for item in event['items']:
        if 'Put' in item:
            table_name = dynamodb_arn_prefix + tables[item['Put']['TableName']]
            raw_item = item['Put']['Item']
            type_serializer = TypeSerializer()
            serialized_item = {k: type_serializer.serialize(v) for k, v in raw_item.items()}
            transact_items.append({
                'Put': {
                    'TableName': table_name,
                    'Item': serialized_item
                }
            })
        if 'Delete' in item:
            table_name = dynamodb_arn_prefix + tables[item['Delete']['TableName']]
            key = item['Delete']['Key']
            type_serializer = TypeSerializer()
            serialized_key = {k: type_serializer.serialize(v) for k, v in key.items()}

            transact_items.append({
                'Delete': {
                    'TableName': table_name,
                    'Key': serialized_key
                }
            })
    client = boto3.client('dynamodb')
    response = client.transact_write_items(TransactItems=transact_items)
    return response

def read_db(event):
    dynamodb = boto3.resource('dynamodb')
    dynamodb_table = dynamodb_arn_prefix + tables[event.get('table')]
    print('data:', json.dumps(event.get('data')))
    payload = event.get('data')
    table = dynamodb.Table(dynamodb_table)
    response_dict = table.query(**payload.get('query'))
    return response_dict

def read_logs(event):
    logs = boto3.client('logs')
    payload = event.get('data')
    job_id = payload.get('job_id')
    log_group_name = f'/infraweave/{region}/{environment}/runner'
    log_stream_name = f'ecs/runner/{job_id}'
    response_dict = logs.get_log_events(
        logGroupName=log_group_name,
        logStreamName=log_stream_name,
        startFromHead=True
    )
    return response_dict

def upload_file_base64(event):
    s3 = boto3.client('s3')
    payload = event.get('data')
    bucket = buckets[payload.get('bucket_name')]
    base64_body = payload.get('base64_content')
    binary_body = base64.b64decode(base64_body)
    s3.put_object(
        Bucket=bucket,
        Key=payload.get('key'),
        Body=binary_body
    )

def generate_presigned_url(event):
    s3 = boto3.client(
        's3',
        region_name=region, 
        endpoint_url=f'https://s3.{region}.amazonaws.com', # https://github.com/boto/boto3/issues/2989
        config=Config(signature_version='s3v4'), # Modern version, required for SSE-KMS encryption
    )
    payload = event.get('data')
    url = s3.generate_presigned_url(
        ClientMethod='get_object',
        Params={
            'Bucket': buckets[payload.get('bucket_name')],
            'Key': payload.get('key')
        },
        ExpiresIn=payload.get('expires_in')
    )
    return {'url': url}

def start_runner(event):
    ecs = boto3.client('ecs')
    payload = event.get('data')
    res = ecs.run_task(
        cluster=ecs_cluster_name,
        taskDefinition=ecs_task_definition,
        launchType='FARGATE',
        overrides={
            'cpu': payload.get('cpu'),
            'memory': payload.get('memory'),
            'containerOverrides': [{
                'name': 'runner',
                'cpu': int(payload.get('cpu')),
                'memory': int(payload.get('memory')),
                'environment': [
                    {
                        "name": "PAYLOAD",
                        "value": json.dumps(payload)
                    }
                ]
            }]
        },
        networkConfiguration={
            'awsvpcConfiguration': {
                'subnets': [os.environ.get('SUBNET_ID')],
                'securityGroups': [os.environ.get('SECURITY_GROUP_ID')],
                'assignPublicIp': 'ENABLED'
            }
        },
        count=1
    )
    print('res:', res)
    resp = {'job_id': res['tasks'][0]['taskArn'].split('/')[-1]}
    return resp

def publish_notification(event):
    sns = boto3.client('sns')
    payload = event.get('data', {})

    message_data = payload.get('message')
    subject = payload.get('subject', 'Unkown Subject')

    if isinstance(message_data, dict):
        message_str = json.dumps(message_data)
    else:
        message_str = str(message_data)

    response = sns.publish(
        TopicArn=notification_topic_arn,
        Subject=subject,
        Message=message_str,
    )

    return response

def get_environment_variables(event):
    return {
        'statusCode': 200,
        'body': {
            "DYNAMODB_TF_LOCKS_TABLE_ARN": os.environ.get('DYNAMODB_TF_LOCKS_TABLE_ARN'),
            "TF_STATE_S3_BUCKET": os.environ.get('TF_STATE_S3_BUCKET'),
            "REGION": os.environ.get('REGION'),
        }
    }

processes = {
    'insert_db': insert_db,
    'transact_write': transact_write,
    'upload_file_base64': upload_file_base64,
    'read_db': read_db,
    'start_runner': start_runner,
    'read_logs': read_logs,
    'generate_presigned_url': generate_presigned_url,
    'publish_notification': publish_notification,
    'get_environment_variables': get_environment_variables,
}

def handler(event, context):
    print(event)
    ev = event.get('event')

    if ev not in processes:
        return {
            'statusCode': 400,
            'body': json.dumps(f'Invalid event type ({ev})')
        }
    return processes[ev](event)
