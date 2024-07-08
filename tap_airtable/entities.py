from dataclasses import dataclass
from typing import Any, Union, cast

from singer_sdk import typing as th
from slugify import slugify

from tap_airtable.types import AIRTABLE_TO_SINGER_MAPPING


@dataclass
class AirtableField:
    field_type: Union[str, list[str]]
    id: str
    name: str
    is_formula: bool = False

    @property
    def singer_type(self) -> type[th.JSONTypeHelper[Any]]:
        if isinstance(self.field_type, list) and self.is_formula:
            # Make it the union of each type in the list
            return cast(type[th.JSONTypeHelper[Any]], th.CustomType({'type': [type_  for field_type in self.field_type for type_ in AIRTABLE_TO_SINGER_MAPPING[field_type].type_dict['type']]}))
        else:
            return cast(type[th.JSONTypeHelper[Any]], AIRTABLE_TO_SINGER_MAPPING[self.field_type])
        

    def to_singer_property(self) -> th.Property[Any]:
        return th.Property(slugify(self.name, separator="_"), self.singer_type, required=False)


@dataclass
class AirtableTable:
    id: str
    name: str
    fields: list[AirtableField]

    def to_singer_schema(self) -> th.PropertiesList:
        return th.PropertiesList(
            th.Property("id", th.StringType, required=True),
            th.Property("createdtime", th.DateTimeType, required=True),
            *(field.to_singer_property() for field in self.fields),
        )

    def get_formula_fields(self) -> list[str]:
        return [field.name for field in self.fields if field.is_formula]


@dataclass
class AirtableBase:
    id: str
    name: str
    tables: list[AirtableTable]
