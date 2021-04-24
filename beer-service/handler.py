import json
import requests
import boto3
import base64
import msgpack
import os

def get_raw_beers(event, context):
    kinesis = boto3.client('kinesis')

    headers = {
        "Accept": "application/json",
        "Content-Type": "application/json"
    }
    get_request = requests.get(
        'https://api.punkapi.com/v2/beers/random',headers=headers)
    
    if(get_request.status_code == 200):
        beer_data = get_request.json()[0]
        record = {'Data':json.dumps(beer_data), 'PartitionKey' : str(beer_data['id'])}
    
        kinesis.put_record(
            Data=record['Data'],
            StreamName=os.environ['KINESIS_STREAM_NAME'],
            PartitionKey=record['PartitionKey']
        )
    
        response = {
            "statusCode": 200,
            "body": json.dumps(record)
        }
    else:
        response = {
            "statusCode": 400,
            "body": json.dumps(get_request.text)
        }
    
    return response

def clean_and_save_beers(event, context):
    final_table_keys = ['id','name','abv','ibu','target_fg','target_og','ebc','srm','ph']

    cleaned_beers  = []
    for record in event['records']:
        payload = {key:value for key,value in json.loads(base64.b64decode(record['data'])).items()
            if key in final_table_keys
        }
        print(f"record payload: {payload}")

        # Do custom processing on the payload here
        output_record = {
            'recordId': record['recordId'],
            'result': 'Ok',
            'data': base64.b64encode(json.dumps(payload).encode('utf-8') + b'\n').decode('utf-8')
        }
        print(f"output_record: {output_record}")
        cleaned_beers.append(output_record)

    print('Successfully processed {} records.'.format(len(event['records'])))
    return {'records': cleaned_beers}