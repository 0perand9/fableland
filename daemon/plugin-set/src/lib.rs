// Written by plugins/assemble: the plugins compiled into this build.
pub fn all() -> Vec<fable_plugin::Entry> {
    vec![
        fable_plugin::Entry { manifest: include_str!("../../../plugins/arr/plugin.json"), plugin: Some(fable_arr::plugin()) },
        fable_plugin::Entry { manifest: include_str!("../../../plugins/crypto/plugin.json"), plugin: Some(fable_crypto::plugin()) },
        fable_plugin::Entry { manifest: include_str!("../../../plugins/movies/plugin.json"), plugin: Some(fable_movies::plugin()) },
    ]
}
