"""Stream type classes for tap-airtable."""

from collections.abc import Iterable
from typing import Any, ClassVar, Optional, Union

from singer_sdk.streams import Stream
from slugify import slugify

from tap_airtable.client import AirtableClient
from tap_airtable.entities import AirtableTable


class BaseAirtableStream(Stream):
    primary_keys: ClassVar = ["id"]
    original_airtable_table: AirtableTable
    base_id: str
    replication_key = None
    
    def get_records(
        self, context: Optional[dict[str, Any]]
    ) -> Iterable[Union[dict[str, Any], tuple[dict[str, Any], dict[str, Any]]]]:
        client = AirtableClient(self.config["token"])
        formula_fields = self.original_airtable_table.get_formula_fields()

        for record in client.get_records(self.base_id, self.original_airtable_table.id):
            fields = record.pop("fields", {})
            for key, value in fields.items():
                if key in formula_fields:
                    value = self._handle_special_values(value)
                fields[key] = value
            yield {slugify(key, separator="_"): value for key, value in {**record, **fields}.items()}
    
    def _handle_special_values(self, value: Any) -> Any:
        if isinstance(value, dict):
            if 'error' in value and value['error'] == '#ERROR!':
                value = '#ERROR!'
            elif 'specialValue' in value:
                if value['specialValue'] == 'NaN':
                    value = float('nan')
                elif value['specialValue'] == 'Infinity':
                    value = float('inf')
        return value

def airtable_stream_factory(table_base_id: str, table: AirtableTable) -> type[BaseAirtableStream]:
    class AirtableStream(BaseAirtableStream):
        original_airtable_table = table
        name = slugify(table.name, separator="_")
        base_id = table_base_id

        @property
        def schema(self) -> dict[str, Any]:
            return table.to_singer_schema().to_dict()

    AirtableStream.__name__ = f"{table.name.title()}AirtableStream"
    return AirtableStream
