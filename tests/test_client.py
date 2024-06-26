import pytest
import requests
import requests_mock
from tap_airtable.client import AirtableClient, NonRetryableError

@pytest.fixture
def airtable_client():
    return AirtableClient(token="fake_token")

@pytest.fixture
def requests_mock_adapter():
    with requests_mock.Mocker() as m:
        yield m

def test_get_with_200_response(airtable_client, requests_mock_adapter):
    requests_mock_adapter.get("https://api.airtable.com/v0/test_endpoint", text='{"data": "test"}')
    response = airtable_client._get("test_endpoint")
    assert response.json() == {"data": "test"}

def test_get_with_429_response(airtable_client, requests_mock_adapter):
    requests_mock_adapter.get("https://api.airtable.com/v0/test_endpoint", status_code=429)
    with pytest.raises(requests.HTTPError):
        airtable_client._get("test_endpoint")

def test_get_with_400_response(airtable_client, requests_mock_adapter):
    requests_mock_adapter.get("https://api.airtable.com/v0/test_endpoint", status_code=400, text='Bad Request')
    with pytest.raises(NonRetryableError):
        airtable_client._get("test_endpoint")

def test_get_base_schema(airtable_client, requests_mock_adapter):
    mock_response = {"tables": [{"id": "tbl123", "name": "Test Table", "fields": []}]}
    requests_mock_adapter.get("https://api.airtable.com/v0/meta/bases/base123/tables", json=mock_response)
    schema = airtable_client._get_base_schema("base123")
    assert schema == mock_response["tables"]

def test_map_field_type_formula_with_result(airtable_client):
    field = {"type": "formula",
            "options": {
                "isValid": "true",
                "formula": "SUM({fldf82WQBqZkvrYWR},{fldiGss4dvzDqPuqr},{fldbJtC0hYnUHSYuy}, {fld99YG0EGM0uvn1q},{fldWlAQ5dZUtq77Vy},{fldjz4RFBLMLQHDxz},{fldQsBEv0OV0yR91f}, {fld8Rysm79Q0TwNhh}, {fldmHDA67quleaFef},{fldLFfTFEPthOEAhf}, {fldJecvcAVQ2R6y9I}, {fldJtx7D2Zt8YvHHY} )",
                "referencedFieldIds": [
                    "fldf82WQBqZkvrYWR",
                    "fldiGss4dvzDqPuqr",
                    "fldbJtC0hYnUHSYuy",
                    "fld99YG0EGM0uvn1q",
                    "fldWlAQ5dZUtq77Vy",
                    "fldjz4RFBLMLQHDxz",
                    "fldQsBEv0OV0yR91f",
                    "fld8Rysm79Q0TwNhh",
                    "fldmHDA67quleaFef",
                    "fldLFfTFEPthOEAhf",
                    "fldJecvcAVQ2R6y9I",
                    "fldJtx7D2Zt8YvHHY"
                ],
                "result": {
                    "type": "currency",
                    "options": { "precision": 0, "symbol": "$" }
                }
            },
    }
    assert airtable_client.map_field_type(field) == "currency"

def test_map_field_type_formula_without_result(airtable_client):
    field = {"type": "formula", "options": {}}
    assert airtable_client.map_field_type(field) == "formula"

def test_map_field_type_non_formula(airtable_client):
    field = {"type": "text"}
    assert airtable_client.map_field_type(field) == "text"

# Example test for get_records, assuming pagination and mocking two pages of records
def test_get_records_pagination(airtable_client, requests_mock_adapter):
    page_1 = {"records": [{"id": "rec1"}], "offset": "page_2"}
    page_2 = {"records": [{"id": "rec2"}]}
    requests_mock_adapter.get("https://api.airtable.com/v0/base123/table123", [{'json': page_1, 'status_code': 200}, {'json': page_2, 'status_code': 200}])
    
    records = list(airtable_client.get_records("base123", "table123"))
    assert len(records) == 2
    assert records[0]["id"] == "rec1"
    assert records[1]["id"] == "rec2"

@pytest.fixture
def mock_response():
    return {
        "bases": [
            {"id": "base1", "name": "Base 1"},
            {"id": "base2", "name": "Base 2"}
        ]
    }

def test_get_bases_success(airtable_client, mock_response):
    with requests_mock.Mocker() as m:
        # Mock the initial request for getting bases
        m.get("https://api.airtable.com/v0/meta/bases", json=mock_response)
        
        # Add mock responses for each base's schema request
        for base in mock_response["bases"]:
            mock_base_schema = {"tables": [{"id": "tbl123", "name": "Test Table", "fields": []}]}
            m.get(f"https://api.airtable.com/v0/meta/bases/{base['id']}/tables", json=mock_base_schema)
        
        # Now calling get_bases should not raise NoMockAddress
        bases = airtable_client.get_bases()
        assert len(bases) == 2
        assert bases[0].id == "base1"
        assert bases[1].id == "base2"

def test_get_bases_missing_ids(airtable_client, mock_response):
    with requests_mock.Mocker() as m:
        m.get("https://api.airtable.com/v0/meta/bases", json=mock_response)
        with pytest.raises(ValueError) as excinfo:
            airtable_client.get_bases(base_ids=["base3"])
        assert "Base ids missing {'base3'}" in str(excinfo.value)

def test_get_bases_http_error(airtable_client):
    with requests_mock.Mocker() as m:
        m.get("https://api.airtable.com/v0/meta/bases", status_code=500)
        with pytest.raises(requests.HTTPError):
            airtable_client.get_bases()

def test_get_bases_non_retryable_error(airtable_client):
    with requests_mock.Mocker() as m:
        m.get("https://api.airtable.com/v0/meta/bases", status_code=400, text="Bad Request")
        with pytest.raises(NonRetryableError) as excinfo:
            airtable_client.get_bases()
        assert "Server response: 400, Bad Request" in str(excinfo.value)