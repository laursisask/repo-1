import math
import pytest
from unittest.mock import MagicMock, patch
from singer_sdk import Tap

from tap_airtable.streams import airtable_stream_factory
from tap_airtable.entities import AirtableTable, AirtableField

@pytest.fixture
def mock_tap():
    return MagicMock()

@pytest.fixture
def airtable_field_normal():
    return AirtableField(field_type="singleLineText", id="1", name="NormalField", is_formula=False)

@pytest.fixture
def airtable_field_formula():
    return AirtableField(field_type="formula", id="2", name="FormulaField", is_formula=True)

@pytest.fixture
def airtable_table(airtable_field_normal, airtable_field_formula):
    return AirtableTable(id="tbl123", name="TestTable", fields=[airtable_field_normal, airtable_field_formula])

@pytest.fixture
def base_airtable_stream(mock_tap, airtable_table):
    stream = airtable_stream_factory("app123", airtable_table)
    instance = stream(tap=mock_tap)
    instance._config = {"token": "fake_token"}
    return instance

@pytest.fixture
def mock_airtable_client():
    with patch('tap_airtable.streams.AirtableClient') as mock:
        yield mock

def test_get_records_normal_field(base_airtable_stream, mock_airtable_client):
    mock_airtable_client.return_value.get_records.return_value = [
        {"id": "rec1", "fields": {"NormalField": "Value1"}}
    ]
    records = list(base_airtable_stream.get_records(None))
    assert len(records) == 1
    print(records[0])
    assert records[0]["normalfield"] == "Value1"

def test_get_records_formula_field_special_values(base_airtable_stream, mock_airtable_client):
    mock_airtable_client.return_value.get_records.return_value = [
        {"id": "rec1", "fields": {"FormulaField": {"error": "#ERROR!"}}},
        {"id": "rec2", "fields": {"FormulaField": {"specialValue": "NaN"}}},
        {"id": "rec3", "fields": {"FormulaField": {"specialValue": "Infinity"}}}
    ]
    records = list(base_airtable_stream.get_records(None))
    assert len(records) == 3
    assert records[0]["formulafield"] == "#ERROR!"
    assert records[1]["formulafield"] == str(float('nan'))
    assert records[2]["formulafield"] == str(float('inf'))  

def test_handle_special_values(base_airtable_stream):
    assert base_airtable_stream._handle_special_values({"error": "#ERROR!"}) == "#ERROR!"
    assert base_airtable_stream._handle_special_values({"specialValue": "NaN"}) == str(float('nan'))
    assert base_airtable_stream._handle_special_values({"specialValue": "Infinity"}) == str(float('inf'))
    assert base_airtable_stream._handle_special_values("NormalValue") == "NormalValue"