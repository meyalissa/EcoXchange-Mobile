/// Non-web stub. Never called -- [isMapsApiKeyConfigured] only reaches this
/// branch's counterpart (maps_key_gate_web.dart) when `kIsWeb` is true, and
/// mobile/desktop always uses the MethodChannel path instead.
bool hasWebMapsKey() => false;
