from _typeshed import Incomplete

class PostNotificationEndpoint:
    openapi_types: Incomplete
    attribute_map: Incomplete
    discriminator_value_class_map: Incomplete
    discriminator: str
    def __init__(self, type: Incomplete | None = ...) -> None: ...
    @property
    def type(self): ...
    @type.setter
    def type(self, type) -> None: ...
    def get_real_child_model(self, data): ...
    def to_dict(self): ...
    def to_str(self): ...
    def __eq__(self, other): ...
    def __ne__(self, other): ...
