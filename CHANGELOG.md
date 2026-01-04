# Changelog

## [2.16.0](https://github.com/stevearc/oil.nvim/compare/v2.15.0...v2.16.0) (2026-01-02)


### Features

* add callback for handling buffer opening ([#638](https://github.com/stevearc/oil.nvim/issues/638)) ([dfb09e8](https://github.com/stevearc/oil.nvim/commit/dfb09e87bfb6d0d4d7896211dc0f18a40747875d))
* add OilEmpty highlight group ([#689](https://github.com/stevearc/oil.nvim/issues/689)) ([b9ab05f](https://github.com/stevearc/oil.nvim/commit/b9ab05fe5abad224c6d70b80a4b3f38e5201204b))
* **clipboard:** pasting from system clipboard can delete original (cut) ([#649](https://github.com/stevearc/oil.nvim/issues/649)) ([f55ebb0](https://github.com/stevearc/oil.nvim/commit/f55ebb007946b57561e7c337fdb1fd4d4622df33))
* copy/paste to system clipboard ([#559](https://github.com/stevearc/oil.nvim/issues/559)) ([4c9bdf0](https://github.com/stevearc/oil.nvim/commit/4c9bdf0d839932617cdb25ed46a2f7bb1e090f77))
* new adapter for S3 buckets ([#677](https://github.com/stevearc/oil.nvim/issues/677)) ([e5bd931](https://github.com/stevearc/oil.nvim/commit/e5bd931edb93a48a3a282f43992c5495966f5ba9))
* support multicursor.nvim ([#696](https://github.com/stevearc/oil.nvim/issues/696)) ([756dec8](https://github.com/stevearc/oil.nvim/commit/756dec855b4811f2d27f067a3aca477f368d99f5))


### Bug Fixes

* args.count of 0 is not used as size ([#695](https://github.com/stevearc/oil.nvim/issues/695)) ([bbfa7cb](https://github.com/stevearc/oil.nvim/commit/bbfa7cba85967dc9dbfe0ca486fd4b17084bf846))
* better detection of oil buffers ([#589](https://github.com/stevearc/oil.nvim/issues/589)) ([548587d](https://github.com/stevearc/oil.nvim/commit/548587d68b55e632d8a69c92cefd981f360634fa))
* change default border config to nil ([#643](https://github.com/stevearc/oil.nvim/issues/643)) ([200df01](https://github.com/stevearc/oil.nvim/commit/200df01e4b92d0010a3bfbde92b91a4ef5a5c9db))
* clean up empty buffer when opening in new tab ([#616](https://github.com/stevearc/oil.nvim/issues/616)) ([5b6068a](https://github.com/stevearc/oil.nvim/commit/5b6068aad7d2057dd399fac73b7fb2cdf23ccd6e))
* command modifiers for :Oil ([#691](https://github.com/stevearc/oil.nvim/issues/691)) ([cbcb3f9](https://github.com/stevearc/oil.nvim/commit/cbcb3f997f6f261c577b943ec94e4ef55108dd95))
* don't apply oil window options to non-directory oil buffers ([7e1cd77](https://github.com/stevearc/oil.nvim/commit/7e1cd7703ff2924d7038476dcbc04b950203b902))
* file time column escapes ()[] chars in parser ([#603](https://github.com/stevearc/oil.nvim/issues/603)) ([ba1f50a](https://github.com/stevearc/oil.nvim/commit/ba1f50a9a81f65c07af584065ab9a5ad2a9e5fe0))
* glob formatting on windows in neovim nightly ([#631](https://github.com/stevearc/oil.nvim/issues/631)) ([08c2bce](https://github.com/stevearc/oil.nvim/commit/08c2bce8b00fd780fb7999dbffdf7cd174e896fb))
* handle empty LSP glob patterns ([#702](https://github.com/stevearc/oil.nvim/issues/702)) ([963c8d2](https://github.com/stevearc/oil.nvim/commit/963c8d2c5538c4a896a31f396b8a5a2683e254dc))
* indexing nil when env vars does not exist ([#601](https://github.com/stevearc/oil.nvim/issues/601)) ([ab887d9](https://github.com/stevearc/oil.nvim/commit/ab887d926c2665a708fbe9e6c4654042cc5f4c60))
* multicursor when opened with --preview ([#701](https://github.com/stevearc/oil.nvim/issues/701)) ([78ed0cf](https://github.com/stevearc/oil.nvim/commit/78ed0cf7d9a64280d621960af4be7872aa650417))
* open files under cwd with relative name ([#693](https://github.com/stevearc/oil.nvim/issues/693)) ([6340494](https://github.com/stevearc/oil.nvim/commit/634049414b9ba7b827f050dc5a873bf68944c640))
* pass bufnr to constrain_cursor ([#574](https://github.com/stevearc/oil.nvim/issues/574)) ([54fe7dc](https://github.com/stevearc/oil.nvim/commit/54fe7dca365e2b917ee269744055320c1f29380d))
* prevent E565 error when opening directories with nvim . ([#608](https://github.com/stevearc/oil.nvim/issues/608)) ([685cdb4](https://github.com/stevearc/oil.nvim/commit/685cdb4ffa74473d75a1b97451f8654ceeab0f4a))
* scratch preview method ([#628](https://github.com/stevearc/oil.nvim/issues/628)) ([bbad9a7](https://github.com/stevearc/oil.nvim/commit/bbad9a76b2617ce1221d49619e4e4b659b3c61fc))
* send_to_quickfix opens loclist when specified ([#687](https://github.com/stevearc/oil.nvim/issues/687)) ([01cb3a8](https://github.com/stevearc/oil.nvim/commit/01cb3a8ad7d5e8707041edc775af83dbf33838f4))
* silent handling when buffer has no oil adapter ([#573](https://github.com/stevearc/oil.nvim/issues/573)) ([d7c61c7](https://github.com/stevearc/oil.nvim/commit/d7c61c70849ec99f005615c4175118986f200e4f))
* ssh adapter supports iso8601 dates ([#635](https://github.com/stevearc/oil.nvim/issues/635)) ([1498d2f](https://github.com/stevearc/oil.nvim/commit/1498d2fccff75a1321e92e4aa03ff220f87cc27e))
* support natural ordering for numbers with &gt;12 digits ([#652](https://github.com/stevearc/oil.nvim/issues/652)) ([07f80ad](https://github.com/stevearc/oil.nvim/commit/07f80ad645895af849a597d1cac897059d89b686))
* **trash-win:** don't hang when `shellslash` is enabled ([#592](https://github.com/stevearc/oil.nvim/issues/592)) ([8649818](https://github.com/stevearc/oil.nvim/commit/8649818fb29322a8ee24c5cd2cd7b2f6c40258a3))
* use `g~` instead of overriding the builtin `~` mapping ([#694](https://github.com/stevearc/oil.nvim/issues/694)) ([15a2b21](https://github.com/stevearc/oil.nvim/commit/15a2b21eda3c94816b9449590425cdcffd8b836a))

## [2.15.0](https://github.com/stevearc/oil.nvim/compare/v2.14.0...v2.15.0) (2025-02-13)


### Features

* add support for bufnr in column rendering functions ([#575](https://github.com/stevearc/oil.nvim/issues/575)) ([8abc58b](https://github.com/stevearc/oil.nvim/commit/8abc58b038f84078121ab1cac6ecad0163fe1635))
* API to automatically open preview window after opening oil ([#339](https://github.com/stevearc/oil.nvim/issues/339)) ([57528bf](https://github.com/stevearc/oil.nvim/commit/57528bf9c58080ca891e8d362d0a578895c136ce))
* can selectively add entries to quickfix ([#564](https://github.com/stevearc/oil.nvim/issues/564)) ([b594b9a](https://github.com/stevearc/oil.nvim/commit/b594b9a9052618669ccf6520b2d0c0d942eb8118))
* floating window max width/height can be percentages ([#553](https://github.com/stevearc/oil.nvim/issues/553)) ([1df90fa](https://github.com/stevearc/oil.nvim/commit/1df90faf927e78f5aacf278abd0bfdcb5f45e825))
* most moves and copies will copy the undofile ([#583](https://github.com/stevearc/oil.nvim/issues/583)) ([32dd3e3](https://github.com/stevearc/oil.nvim/commit/32dd3e378d47673679e76a773451f82f971a66df))
* pass oil bufnr to custom filename highlight function ([#552](https://github.com/stevearc/oil.nvim/issues/552)) ([f5c563a](https://github.com/stevearc/oil.nvim/commit/f5c563a074a38cee5a09f98e98b74dcd2c322490))


### Bug Fixes

* crash in preview on nvim 0.8 ([81b2c5f](https://github.com/stevearc/oil.nvim/commit/81b2c5f04ae24a8c83b20ecbd017fecac15faca0))
* directory rendering with custom highlights ([#551](https://github.com/stevearc/oil.nvim/issues/551)) ([a6a4f48](https://github.com/stevearc/oil.nvim/commit/a6a4f48b14b4a51fded531c86f6c04b4503a2ef8))
* disable_preview respected when preview_method != "load" ([#577](https://github.com/stevearc/oil.nvim/issues/577)) ([7cde5aa](https://github.com/stevearc/oil.nvim/commit/7cde5aab10f564408e9ac349d457d755422d58cd))
* error when non-current oil buffer has validation errors ([#561](https://github.com/stevearc/oil.nvim/issues/561)) ([8d11a2a](https://github.com/stevearc/oil.nvim/commit/8d11a2abf3039b1974d4acd65fbc83ada2ca1084))
* gracefully handle fs_stat failures ([#558](https://github.com/stevearc/oil.nvim/issues/558)) ([7c26a59](https://github.com/stevearc/oil.nvim/commit/7c26a59ac0061b199bf9f44b19d45cfadd9b14f5))
* guard against nil metadata values ([#548](https://github.com/stevearc/oil.nvim/issues/548)) ([254bc66](https://github.com/stevearc/oil.nvim/commit/254bc6635cb3f77e6e9a89155652f368e5535160))
* more consistent cursor position when entering a new directory ([#536](https://github.com/stevearc/oil.nvim/issues/536)) ([c80fa5c](https://github.com/stevearc/oil.nvim/commit/c80fa5c415b882c1c694a32748cea09b7dafc2c5))
* more robust parsing of custom column timestamp formats ([#582](https://github.com/stevearc/oil.nvim/issues/582)) ([5313690](https://github.com/stevearc/oil.nvim/commit/5313690956d27cc6b53d5a2583df05e717c59b16))
* open files in correct window from floating oil ([#560](https://github.com/stevearc/oil.nvim/issues/560)) ([83ac518](https://github.com/stevearc/oil.nvim/commit/83ac5185f79ab8d869bccea792dc516ad02ad06e))
* preview sometimes causes oil buffers to be stuck in unloaded state ([#563](https://github.com/stevearc/oil.nvim/issues/563)) ([1488f0d](https://github.com/stevearc/oil.nvim/commit/1488f0d96b1cb820dd12f05a7bf5283a631a7c4d))
* stat files if fs_readdir doesn't provide a type ([#543](https://github.com/stevearc/oil.nvim/issues/543)) ([c6a39a6](https://github.com/stevearc/oil.nvim/commit/c6a39a69b2df7c10466f150dde0bd23e49c1fba3))
* support permissions checks on windows and virtual filesystems ([#555](https://github.com/stevearc/oil.nvim/issues/555)) ([7041528](https://github.com/stevearc/oil.nvim/commit/7041528bdedb350ad66e650684deec8456e053cc))
* work around incorrect link detection on windows ([#557](https://github.com/stevearc/oil.nvim/issues/557)) ([09fa1d2](https://github.com/stevearc/oil.nvim/commit/09fa1d22f5edf0730824d2b222d726c8c81bbdc9))

## [2.14.0](https://github.com/stevearc/oil.nvim/compare/v2.13.0...v2.14.0) (2024-12-21)


### Features

* add `win_options` to `preview_win` ([#514](https://github.com/stevearc/oil.nvim/issues/514)) ([bbeed86](https://github.com/stevearc/oil.nvim/commit/bbeed86bde134da8d09bed64b6aa0d65642e6b23))
* add highlight group for orphaned links ([#502](https://github.com/stevearc/oil.nvim/issues/502)) ([740b8fd](https://github.com/stevearc/oil.nvim/commit/740b8fd425a2b77f7f40eb5ac155ebe66ff9515c))
* better merging of action desc when overriding keymaps ([f2b3249](https://github.com/stevearc/oil.nvim/commit/f2b324933f4d505cff6f7d445fd61fad02dcd9ae))
* config option to customize filename highlight group ([#508](https://github.com/stevearc/oil.nvim/issues/508)) ([99ce32f](https://github.com/stevearc/oil.nvim/commit/99ce32f4a2ecf76263b72fcc31efb163faa1a941))
* config option to disable previewing a file ([3fa3161](https://github.com/stevearc/oil.nvim/commit/3fa3161aa9515ff6a7cf7e44458b6a2114262870))
* disable preview for large files ([#511](https://github.com/stevearc/oil.nvim/issues/511)) ([c23fe08](https://github.com/stevearc/oil.nvim/commit/c23fe08e0546d9efc242e19f0d829efa7e7b2743))
* highlight groups for hidden files ([#459](https://github.com/stevearc/oil.nvim/issues/459)) ([60e6896](https://github.com/stevearc/oil.nvim/commit/60e68967e51ff1ecd264c29e3de0d52bfff22df3))
* option to quite vim if oil is closed as last buffer ([#491](https://github.com/stevearc/oil.nvim/issues/491)) ([81cc9c3](https://github.com/stevearc/oil.nvim/commit/81cc9c3f62ddbef3687931d119e505643496fa0a))
* use scratch buffer for file previews ([#467](https://github.com/stevearc/oil.nvim/issues/467)) ([21705a1](https://github.com/stevearc/oil.nvim/commit/21705a1debe6d85a53c138ab944484b685432b2b))


### Bug Fixes

* cursor sometimes does not hover previous file ([8ea40b5](https://github.com/stevearc/oil.nvim/commit/8ea40b5506115b6d355e304dd9ee5089f7d78601))
* don't take over the preview window until it's opened for oil ([#532](https://github.com/stevearc/oil.nvim/issues/532)) ([78ab7ca](https://github.com/stevearc/oil.nvim/commit/78ab7ca1073731ebdf82efa474202defa028d5a4))
* handle files with newlines in the name ([#534](https://github.com/stevearc/oil.nvim/issues/534)) ([dba0375](https://github.com/stevearc/oil.nvim/commit/dba037598843973b8c54bc5ce0318db4a0da439d))
* image.nvim previews with preview_method=scratch ([5acab3d](https://github.com/stevearc/oil.nvim/commit/5acab3d8a9bc85a571688db432f2702dd7d901a4))
* improper file name escaping ([#530](https://github.com/stevearc/oil.nvim/issues/530)) ([7a55ede](https://github.com/stevearc/oil.nvim/commit/7a55ede5e745e31ea8e4cb5483221524922294bf))
* set alternate when using floating windows ([#526](https://github.com/stevearc/oil.nvim/issues/526)) ([c5f7c56](https://github.com/stevearc/oil.nvim/commit/c5f7c56644425e2b77e71904da98cda0331b3342))
* work around performance issue with treesitter, folds, and large directories ([da93d55](https://github.com/stevearc/oil.nvim/commit/da93d55e32d73a17c447067d168d80290ae96590))


### Performance Improvements

* change default view_options.natural_order behavior to disable on large directories ([01b0b9d](https://github.com/stevearc/oil.nvim/commit/01b0b9d8ef79b7b631e92f6b5fed1c639262d570))
* only sort entries after we have them all ([792f0db](https://github.com/stevearc/oil.nvim/commit/792f0db6ba8b626b14bc127e1ce7247185b3be91))
* optimize rendering cadence ([c96f93d](https://github.com/stevearc/oil.nvim/commit/c96f93d894cc97e76b0871bec4058530eee8ece4))
* replace vim.endswith and vim.startswith with string.match ([4de3025](https://github.com/stevearc/oil.nvim/commit/4de30256c32cd272482bc6df0c6de78ffc389153))

## [2.13.0](https://github.com/stevearc/oil.nvim/compare/v2.12.2...v2.13.0) (2024-11-11)


### Features

* config option to customize floating window title ([#482](https://github.com/stevearc/oil.nvim/issues/482)) ([5d2dfae](https://github.com/stevearc/oil.nvim/commit/5d2dfae655b9b689bd4017b3bdccd52cbee5b92f))
* config option to disable lsp file methods ([#477](https://github.com/stevearc/oil.nvim/issues/477)) ([f60bb7f](https://github.com/stevearc/oil.nvim/commit/f60bb7f793477d99ef1acf39e920bf2ca4e644de))


### Bug Fixes

* actions.preview accepts options ([#497](https://github.com/stevearc/oil.nvim/issues/497)) ([cca1631](https://github.com/stevearc/oil.nvim/commit/cca1631d5ea450c09ba72f3951a9e28105a3632c))
* add trailing slash to directories on yank_entry ([#504](https://github.com/stevearc/oil.nvim/issues/504)) ([42333bb](https://github.com/stevearc/oil.nvim/commit/42333bb46e34dd47e13927010b1dcd30e6e4ca96))
* don't deep merge keymaps ([#510](https://github.com/stevearc/oil.nvim/issues/510)) ([709403c](https://github.com/stevearc/oil.nvim/commit/709403ccd6f22d859c2e42c780ab558ae89284d9))
* guard against nil keymaps ([621f8ba](https://github.com/stevearc/oil.nvim/commit/621f8ba4fa821724e9b646732a26fb2e795fe008))
* only map ~ for normal mode ([#484](https://github.com/stevearc/oil.nvim/issues/484)) ([ccab9d5](https://github.com/stevearc/oil.nvim/commit/ccab9d5e09e2d0042fbbe5b6bd05e82426247067))
* sort keymap help entries by description ([#506](https://github.com/stevearc/oil.nvim/issues/506)) ([52cc8a1](https://github.com/stevearc/oil.nvim/commit/52cc8a1fb35ea6ce1df536143add7ce7215c63c0)), closes [#376](https://github.com/stevearc/oil.nvim/issues/376)

## [2.12.2](https://github.com/stevearc/oil.nvim/compare/v2.12.1...v2.12.2) (2024-09-10)


### Bug Fixes

* ensure win_options are being set on correct window ([#469](https://github.com/stevearc/oil.nvim/issues/469)) ([30e0438](https://github.com/stevearc/oil.nvim/commit/30e0438ff08f197d7ce4a417445ab97ee72efe2d))
* wrap git rm callback in schedule_wrap ([#475](https://github.com/stevearc/oil.nvim/issues/475)) ([b053744](https://github.com/stevearc/oil.nvim/commit/b05374428e5136d9b6c8e1e8e62a75f82283b1f8))


### Performance Improvements

* **view:** avoid running `is_hidden_file` when `show_hidden` is set ([#471](https://github.com/stevearc/oil.nvim/issues/471)) ([0fcd126](https://github.com/stevearc/oil.nvim/commit/0fcd1263a2e8b6200e2b9fd4ab83d40ed8899c54))

## [2.12.1](https://github.com/stevearc/oil.nvim/compare/v2.12.0...v2.12.1) (2024-08-26)


### Bug Fixes

* gracefully handle trashing file that does not exist ([70337eb](https://github.com/stevearc/oil.nvim/commit/70337eb77f53cbff0b7f54f403d5b2b0a9430935))
* process deletes in dir before moving dir ([349bca8](https://github.com/stevearc/oil.nvim/commit/349bca8c3eae4ab78629ed63ee55cc3458a367c0))

## [2.12.0](https://github.com/stevearc/oil.nvim/compare/v2.11.0...v2.12.0) (2024-08-17)


### Features

* add support for `mini.icons` ([#439](https://github.com/stevearc/oil.nvim/issues/439)) ([a543ea5](https://github.com/stevearc/oil.nvim/commit/a543ea598eaef3363fe253e0e11837c1404eb04d))
* allow bufnr optional parameter for get_current_dir function ([#440](https://github.com/stevearc/oil.nvim/issues/440)) ([cc23325](https://github.com/stevearc/oil.nvim/commit/cc2332599f8944076fba29ff7960729b3fcdd71b))
* disable cursor in preview window ([#433](https://github.com/stevearc/oil.nvim/issues/433)) ([b15e4c1](https://github.com/stevearc/oil.nvim/commit/b15e4c1e647b9ddbb75a31caeb720b3b3ce4db54))


### Bug Fixes

* add compatibility for Lua 5.1 ([#456](https://github.com/stevearc/oil.nvim/issues/456)) ([b39a789](https://github.com/stevearc/oil.nvim/commit/b39a78959f3f69e9c1bf43c2634bbddf0af51c3e))
* correctly check if `mini.icons` is actually setup ([#441](https://github.com/stevearc/oil.nvim/issues/441)) ([d5e5657](https://github.com/stevearc/oil.nvim/commit/d5e56574f896120b78cdf56dc1132e76057f8877))
* cursor sometimes disappears after making changes ([#438](https://github.com/stevearc/oil.nvim/issues/438)) ([b5a1abf](https://github.com/stevearc/oil.nvim/commit/b5a1abfde00eead6814cae3321e4c90ff98cfff1))
* Force standard C locale when getting `ls` input for parsing in SSH ([#455](https://github.com/stevearc/oil.nvim/issues/455)) ([71c972f](https://github.com/stevearc/oil.nvim/commit/71c972fbd218723a3c15afcb70421f67340f5a6d))
* handle rare case where file watcher outlives buffer ([fcca212](https://github.com/stevearc/oil.nvim/commit/fcca212c2e966fc3dec1d4baf888e670631d25d1))
* Handle users and groups with spaces over SSH ([#448](https://github.com/stevearc/oil.nvim/issues/448)) ([a6cea1a](https://github.com/stevearc/oil.nvim/commit/a6cea1a5b9bc9351769fe09a547c62fe4b669abd))
* set floating window win_options when buffer changes ([#432](https://github.com/stevearc/oil.nvim/issues/432)) ([b0a6cf9](https://github.com/stevearc/oil.nvim/commit/b0a6cf98982cdcf82b19b0029b734bbbcd24bcc4))

## [2.11.0](https://github.com/stevearc/oil.nvim/compare/v2.10.0...v2.11.0) (2024-07-01)


### Features

* case insensitive sorting ([#429](https://github.com/stevearc/oil.nvim/issues/429)) ([2077cc3](https://github.com/stevearc/oil.nvim/commit/2077cc3358f327aca16c376cdde6ea0b07f14449))
* rename experimental_watch_for_changes -&gt; watch_for_changes ([c7c7ce5](https://github.com/stevearc/oil.nvim/commit/c7c7ce5bd47030ee9c60a859f25695647610b8bd))
* support preview from floating window ([#403](https://github.com/stevearc/oil.nvim/issues/403)) ([59b3dab](https://github.com/stevearc/oil.nvim/commit/59b3dab6f79e147a0d694ee72c26ae883d323340))


### Bug Fixes

* bug in buffer rendering race condition handling ([f6df58a](https://github.com/stevearc/oil.nvim/commit/f6df58ad370f45dbc18c42ffbaefbcf27df14036))
* correctly check group permissions in unix ([#428](https://github.com/stevearc/oil.nvim/issues/428)) ([65c53db](https://github.com/stevearc/oil.nvim/commit/65c53dbe4f2140236590a7568a5f22a77d16be39))
* increase loading display delay to avoid flicker ([#424](https://github.com/stevearc/oil.nvim/issues/424)) ([4c574cf](https://github.com/stevearc/oil.nvim/commit/4c574cf4a2de736d2662d52ce086d8bdf87c49df))

## [2.10.0](https://github.com/stevearc/oil.nvim/compare/v2.9.0...v2.10.0) (2024-06-16)


### Features

* add copy filename action ([#391](https://github.com/stevearc/oil.nvim/issues/391)) ([bbc0e67](https://github.com/stevearc/oil.nvim/commit/bbc0e67eebc15342e73b146a50d9b52e6148161b))
* keymap actions can be parameterized ([96368e1](https://github.com/stevearc/oil.nvim/commit/96368e13e9b1aaacc570e4825b8787307f0d05e1))


### Bug Fixes

* change unknown action name from error to notification ([e5eb20e](https://github.com/stevearc/oil.nvim/commit/e5eb20e88fc03bf89f371032de77f176158b41d3))
* error opening command window from oil float ([#378](https://github.com/stevearc/oil.nvim/issues/378)) ([06a19f7](https://github.com/stevearc/oil.nvim/commit/06a19f77f1a1da37b675635e6f9c5b5d50bcaacd))
* hack around glob issues in LSP rename operations ([#386](https://github.com/stevearc/oil.nvim/issues/386)) ([e5312c3](https://github.com/stevearc/oil.nvim/commit/e5312c3a801e7274fa14e6a56aa10a618fed80c3))
* incorrect default config actions ([#414](https://github.com/stevearc/oil.nvim/issues/414)) ([c82b26e](https://github.com/stevearc/oil.nvim/commit/c82b26eb4ba35c0eb7ec38d88dd400597fb34883))
* notify when changing the current directory ([#406](https://github.com/stevearc/oil.nvim/issues/406)) ([18272ab](https://github.com/stevearc/oil.nvim/commit/18272aba9d00a3176a5443d50dbb4464acc167bd))
* throw error on vim.has call within the lsp/workspace.lua ([#411](https://github.com/stevearc/oil.nvim/issues/411)) ([61f1967](https://github.com/stevearc/oil.nvim/commit/61f1967222365474c6cf7953c569cc94dbcc7acd))
* vim.notify call error ([76bfc25](https://github.com/stevearc/oil.nvim/commit/76bfc25520e4edc98d089d023b4ed06013639849))

## [2.9.0](https://github.com/stevearc/oil.nvim/compare/v2.8.0...v2.9.0) (2024-05-16)


### Features

* can restore Oil progress window when minimized ([fa3820e](https://github.com/stevearc/oil.nvim/commit/fa3820ebf1e8ccf5c7c0f3626d499b2c1aa8bc50))
* experimental support for git operations ([#290](https://github.com/stevearc/oil.nvim/issues/290)) ([1f05774](https://github.com/stevearc/oil.nvim/commit/1f05774e1c2dbc1940104b5c950d5c7b65ec6e0b))


### Bug Fixes

* duplicate create actions ([#334](https://github.com/stevearc/oil.nvim/issues/334)) ([354c530](https://github.com/stevearc/oil.nvim/commit/354c53080a6d7f4f0b2f0cc12e53bede2480b9e5))
* error when opening files from floating oil window ([#355](https://github.com/stevearc/oil.nvim/issues/355)) ([2bc56ad](https://github.com/stevearc/oil.nvim/commit/2bc56ad68afd092af1b2e77dd5d61e156938564c))
* git mv errors when moving empty directory ([#358](https://github.com/stevearc/oil.nvim/issues/358)) ([6a7a10b](https://github.com/stevearc/oil.nvim/commit/6a7a10b6117aface6a25b54906140ad4f7fdabfc))
* gracefully handle new dirs with trailing backslash on windows ([#336](https://github.com/stevearc/oil.nvim/issues/336)) ([be0a1ec](https://github.com/stevearc/oil.nvim/commit/be0a1ecbf0541692a1b9b6e8ea15f5f57db8747a))
* icon column highlight parameter ([#366](https://github.com/stevearc/oil.nvim/issues/366)) ([752563c](https://github.com/stevearc/oil.nvim/commit/752563c59d64a5764cc0743d4fa0aac9ae4a2640))
* race condition when entering oil buffer ([#321](https://github.com/stevearc/oil.nvim/issues/321)) ([c86e484](https://github.com/stevearc/oil.nvim/commit/c86e48407b8a45f9aa8acb2b4512b384ea1eec84))
* **ssh:** bad argument when editing files over ssh ([#370](https://github.com/stevearc/oil.nvim/issues/370)) ([aa0c00c](https://github.com/stevearc/oil.nvim/commit/aa0c00c7fd51982ac476d165cd021f348cf5ea71))
* **ssh:** config option to pass extra args to SCP ([#340](https://github.com/stevearc/oil.nvim/issues/340)) ([3abb607](https://github.com/stevearc/oil.nvim/commit/3abb6077d7d6b09f5eb794b8764223b3027f6807))
* **ssh:** garbled output when directory has broken symlinks ([bcfc0a2](https://github.com/stevearc/oil.nvim/commit/bcfc0a2e01def5019aa14fac2fc6de20dedb6d3d))
* support visual mode when preview window is open ([#315](https://github.com/stevearc/oil.nvim/issues/315)) ([f41d7e7](https://github.com/stevearc/oil.nvim/commit/f41d7e7cd8e4028b03c35d847b4396790ac8bb2d))
* **windows:** convert posix paths before matching LSP watch globs ([#374](https://github.com/stevearc/oil.nvim/issues/374)) ([f630887](https://github.com/stevearc/oil.nvim/commit/f630887cd845a7341bc16488fe8aaecffe3aaa8a))
* **windows:** file operation preview uses only backslash path separator ([#336](https://github.com/stevearc/oil.nvim/issues/336)) ([96f0983](https://github.com/stevearc/oil.nvim/commit/96f0983e754694e592d4313f583cd31eaebfa80d))
* **windows:** navigating into drive letter root directories ([#341](https://github.com/stevearc/oil.nvim/issues/341)) ([f3a31eb](https://github.com/stevearc/oil.nvim/commit/f3a31eba24587bc038592103d8f7e64648292115))
* **windows:** treat both backslash and frontslash as path separators ([#336](https://github.com/stevearc/oil.nvim/issues/336)) ([3b3a6b2](https://github.com/stevearc/oil.nvim/commit/3b3a6b23a120e69ddc980c9d32840ecd521fbff9))

## [2.8.0](https://github.com/stevearc/oil.nvim/compare/v2.7.0...v2.8.0) (2024-04-19)


### Features

* add user autocmds before and after performing actions ([#310](https://github.com/stevearc/oil.nvim/issues/310)) ([e462a34](https://github.com/stevearc/oil.nvim/commit/e462a3446505185adf063566f5007771b69027a1))


### Bug Fixes

* output suppressed when opening files ([#348](https://github.com/stevearc/oil.nvim/issues/348)) ([6c48ac7](https://github.com/stevearc/oil.nvim/commit/6c48ac7dc679c5694a2c0375a5e67773e31d8157))
* **ssh:** escape all file paths for the ssh adapter ([#353](https://github.com/stevearc/oil.nvim/issues/353)) ([8bb35eb](https://github.com/stevearc/oil.nvim/commit/8bb35eb81a48f14c4a1ef480c2bbb87ceb7cd8bb))

## [2.7.0](https://github.com/stevearc/oil.nvim/compare/v2.6.1...v2.7.0) (2024-03-13)


### Features

* add ability to alter lsp file operation timeout ([#317](https://github.com/stevearc/oil.nvim/issues/317)) ([29a06fc](https://github.com/stevearc/oil.nvim/commit/29a06fcc906f57894c1bc768219ba590e03d1121))
* add border config for SSH and keymaps help window ([#299](https://github.com/stevearc/oil.nvim/issues/299)) ([e27cc4e](https://github.com/stevearc/oil.nvim/commit/e27cc4e13812f96c0851de67015030a823cc0fbd))
* do not close preview when switching dirs ([#277](https://github.com/stevearc/oil.nvim/issues/277)) ([bf753c3](https://github.com/stevearc/oil.nvim/commit/bf753c3e3f8736939ad5597f92329dfe7b1df4f5))
* experimental option to watch directory for changes ([#292](https://github.com/stevearc/oil.nvim/issues/292)) ([bcfe7d1](https://github.com/stevearc/oil.nvim/commit/bcfe7d1ec5bbf41dd78726f579a363028d208c1a))
* use natural sort order by default ([#328](https://github.com/stevearc/oil.nvim/issues/328)) ([71b076b](https://github.com/stevearc/oil.nvim/commit/71b076b3afb40663222564c74162db555aeee62d))


### Bug Fixes

* actions.open_external uses explorer.exe in WSL ([#273](https://github.com/stevearc/oil.nvim/issues/273)) ([6953c2c](https://github.com/stevearc/oil.nvim/commit/6953c2c17d8ae7454b28c44c8767eebede312e6f))
* close preview window when leaving oil buffer ([#296](https://github.com/stevearc/oil.nvim/issues/296)) ([132b4ea](https://github.com/stevearc/oil.nvim/commit/132b4ea0740c417b9d717411cab4cf187e1fd095))
* correctly reset bufhidden for formerly previewed buffers ([#291](https://github.com/stevearc/oil.nvim/issues/291)) ([0de8e60](https://github.com/stevearc/oil.nvim/commit/0de8e60e3d8d3d1ff9378526b4722f1ea326e1cb))
* potential leak in experimental file watcher ([c437f3c](https://github.com/stevearc/oil.nvim/commit/c437f3c5b0da0a9cc6a222d87212cce11b80ba75))
* spurious exits from faulty :wq detection ([#221](https://github.com/stevearc/oil.nvim/issues/221)) ([e045ee3](https://github.com/stevearc/oil.nvim/commit/e045ee3b4e06cafd7a6a2acac10f2558e611eaf8))
* window options sometimes not set in oil buffer ([#287](https://github.com/stevearc/oil.nvim/issues/287)) ([17d71eb](https://github.com/stevearc/oil.nvim/commit/17d71eb3d88a79dbc87c6245f8490853a5c38092))
* **windows:** can delete non-ascii filenames to trash ([#323](https://github.com/stevearc/oil.nvim/issues/323)) ([18dfd24](https://github.com/stevearc/oil.nvim/commit/18dfd2458dc741fea683357a17aaa95870b25a3c))

## [2.6.1](https://github.com/stevearc/oil.nvim/compare/v2.6.0...v2.6.1) (2024-01-16)


### Bug Fixes

* crash when LSP client workspace_folders is nil ([#269](https://github.com/stevearc/oil.nvim/issues/269)) ([c4cc824](https://github.com/stevearc/oil.nvim/commit/c4cc8240f1c71defcb67c45da96e44b968d29e5f))
* diagnostic float would not open if scope=cursor ([#275](https://github.com/stevearc/oil.nvim/issues/275)) ([a1af7a1](https://github.com/stevearc/oil.nvim/commit/a1af7a1b593d8d28581ef0de82a6977721601afa))
* **lsp_rename:** handle absolute path glob filters ([#279](https://github.com/stevearc/oil.nvim/issues/279)) ([ec24334](https://github.com/stevearc/oil.nvim/commit/ec24334471e7ccbfb7488910159245dc7327a07d))
* **trash:** mac error deleting dangling symbolic links to trash ([#251](https://github.com/stevearc/oil.nvim/issues/251)) ([49b2b3f](https://github.com/stevearc/oil.nvim/commit/49b2b3f4a50bcd546decf751e5834de9b6f38d97))


### Performance Improvements

* **windows:** use a single powershell process for trash operations ([#271](https://github.com/stevearc/oil.nvim/issues/271)) ([e71b6ca](https://github.com/stevearc/oil.nvim/commit/e71b6caa95bd29225536df64fdcd8fb0f758bb09))

## [2.6.0](https://github.com/stevearc/oil.nvim/compare/v2.5.0...v2.6.0) (2024-01-03)


### Features

* **trash:** support for deleting to windows recycle bin ([#243](https://github.com/stevearc/oil.nvim/issues/243)) ([553b7a0](https://github.com/stevearc/oil.nvim/commit/553b7a0ac129c0e7a7bbde72f9fbfe7c9f4be6c3))

## [2.5.0](https://github.com/stevearc/oil.nvim/compare/v2.4.1...v2.5.0) (2023-12-26)


### Features

* actions for sending oil entries to quickfix ([#249](https://github.com/stevearc/oil.nvim/issues/249)) ([3ffb830](https://github.com/stevearc/oil.nvim/commit/3ffb8309e6eda961c7edb9ecbe6a340fe9e24b43))
* add 'update_on_cursor_moved' option to preview window ([#250](https://github.com/stevearc/oil.nvim/issues/250)) ([ea612fe](https://github.com/stevearc/oil.nvim/commit/ea612fe926a24ea20b2b3856e1ba60bdaaae9383))
* allow multiple hlgroups inside one column ([#240](https://github.com/stevearc/oil.nvim/issues/240)) ([a173b57](https://github.com/stevearc/oil.nvim/commit/a173b5776c66a31ce08552677c1eae7ab015835f))
* constrain_cursor option (closes [#257](https://github.com/stevearc/oil.nvim/issues/257)) ([71b1ef5](https://github.com/stevearc/oil.nvim/commit/71b1ef5edfcee7c58fe611fdd79bfafcb9fb0531))
* option to auto-save files affected by will_rename_files ([#218](https://github.com/stevearc/oil.nvim/issues/218)) ([48d8ea8](https://github.com/stevearc/oil.nvim/commit/48d8ea8f4a6590ef7339ff0fdb97cef3e238dd86))
* refresh action also clears search highlight ([#228](https://github.com/stevearc/oil.nvim/issues/228)) ([8283457](https://github.com/stevearc/oil.nvim/commit/82834573bbca27c240f30087ff642b807ed1872a))
* support all LSP workspace file operations ([#264](https://github.com/stevearc/oil.nvim/issues/264)) ([250e0af](https://github.com/stevearc/oil.nvim/commit/250e0af7a54d750792be8b1d6165b76b6603a867))


### Bug Fixes

* constrain cursor when entering insert mode ([a60c6d1](https://github.com/stevearc/oil.nvim/commit/a60c6d10fd66de275c1d00451c918104ef9b6d10))
* handle opening oil from buffers with foreign schemes ([#256](https://github.com/stevearc/oil.nvim/issues/256)) ([22ab2ce](https://github.com/stevearc/oil.nvim/commit/22ab2ce1d56832588a634e7737404d9344698bd3))
* **trash:** error deleting dangling symbolic links to trash ([#251](https://github.com/stevearc/oil.nvim/issues/251)) ([5d9e436](https://github.com/stevearc/oil.nvim/commit/5d9e4368d49aec00b1e0d9ea520e1403ad6ad634))
* willRename source path ([#248](https://github.com/stevearc/oil.nvim/issues/248)) ([24027ed](https://github.com/stevearc/oil.nvim/commit/24027ed8d7f3ee5c38cfd713915e2e16d89e79b3))


### Performance Improvements

* speed up session loading ([#246](https://github.com/stevearc/oil.nvim/issues/246)) ([b3c24f4](https://github.com/stevearc/oil.nvim/commit/b3c24f4b3b2d38483241292a330cd6eb00734dac))

## [2.4.1](https://github.com/stevearc/oil.nvim/compare/v2.4.0...v2.4.1) (2023-12-01)


### Bug Fixes

* buffer data cleared when setting buflisted = false ([303f318](https://github.com/stevearc/oil.nvim/commit/303f31895e7ce10df250c88c7a5f7d8d9c56f0fc))
* bug copying file multiple times ([05cb825](https://github.com/stevearc/oil.nvim/commit/05cb8257cb9257144e63f41ccfe5a41ba3d1003c))
* crash in ssh and trash adapter detail columns ([#235](https://github.com/stevearc/oil.nvim/issues/235)) ([e89a8f8](https://github.com/stevearc/oil.nvim/commit/e89a8f8adeef2dfab851fd056d38ee7afc97c249))
* oil.select respects splitbelow and splitright ([#233](https://github.com/stevearc/oil.nvim/issues/233)) ([636989b](https://github.com/stevearc/oil.nvim/commit/636989b603fb95032efa9d3e1b3323c8bb533e91))
* preserve buflisted when re-opening oil buffers ([#220](https://github.com/stevearc/oil.nvim/issues/220)) ([6566f45](https://github.com/stevearc/oil.nvim/commit/6566f457e44498adc6835bed5402b38386fa1438))

## [2.4.0](https://github.com/stevearc/oil.nvim/compare/v2.3.0...v2.4.0) (2023-11-15)


### Features

* display ../ entry in oil buffers ([#166](https://github.com/stevearc/oil.nvim/issues/166)) ([d8f0d91](https://github.com/stevearc/oil.nvim/commit/d8f0d91b10ec53da722b0909697b57c2f5368245))
* trash support for linux and mac ([#165](https://github.com/stevearc/oil.nvim/issues/165)) ([6175bd6](https://github.com/stevearc/oil.nvim/commit/6175bd646272335c8db93264760760d8f2a611d5))


### Bug Fixes

* can view drives on Windows ([126a8a2](https://github.com/stevearc/oil.nvim/commit/126a8a23465312683edf646555b3031bfe56796d))
* don't set buflisted on oil buffers ([#220](https://github.com/stevearc/oil.nvim/issues/220)) ([873d505](https://github.com/stevearc/oil.nvim/commit/873d505e5bfdd65317ea97ead8faa6c56bac04c0))
* line parsing for empty columns ([0715f1b](https://github.com/stevearc/oil.nvim/commit/0715f1b0aacef70573ed6300c12039831fbd81c3))
* previewing and editing files on windows ([#214](https://github.com/stevearc/oil.nvim/issues/214)) ([3727410](https://github.com/stevearc/oil.nvim/commit/3727410e4875ad8ba339c585859a9391d643b9ed))
* quit after mutations when :wq or similar ([#221](https://github.com/stevearc/oil.nvim/issues/221)) ([af13ce3](https://github.com/stevearc/oil.nvim/commit/af13ce333f89c54a47e6772b55fed2438ee6957c))

## [2.3.0](https://github.com/stevearc/oil.nvim/compare/v2.2.0...v2.3.0) (2023-11-04)


### Features

* add support for LSP willRenameFiles ([#184](https://github.com/stevearc/oil.nvim/issues/184)) ([8f3c1d2](https://github.com/stevearc/oil.nvim/commit/8f3c1d2d2e4f7b81d19f353c61cb4ccba6a26496))
* make buffer cleanup delay configurable ([#191](https://github.com/stevearc/oil.nvim/issues/191)) ([a9f7f69](https://github.com/stevearc/oil.nvim/commit/a9f7f6927de2ceab01c9dfddd5a0d96330fe6374))


### Bug Fixes

* call vimL function in main loop ([#206](https://github.com/stevearc/oil.nvim/issues/206)) ([8418e94](https://github.com/stevearc/oil.nvim/commit/8418e94734e2572b422aead6e28d5a4c5b543d1f))
* case handling for LSP willRenameFiles ([deba4db](https://github.com/stevearc/oil.nvim/commit/deba4db1aca6e3970c94499401da001694d01138))
* disable swapfile for oil buffers ([#190](https://github.com/stevearc/oil.nvim/issues/190)) ([2e6996b](https://github.com/stevearc/oil.nvim/commit/2e6996b0757c454a8bbf1eb719d0b0b065442213))
* more correct gf binding for ssh files ([1641357](https://github.com/stevearc/oil.nvim/commit/164135793d893efad9ed6f90ac74a1ab54c4182a))
* parse errors when moving files across adapters ([4088efb](https://github.com/stevearc/oil.nvim/commit/4088efb8ff664b6f1624aab5dac6c3fe11d3962c))
* path shortening does proper subpath detection ([054247b](https://github.com/stevearc/oil.nvim/commit/054247b9c1799edd5874231973db621553062a43))
* restore original window when closing floating win ([#208](https://github.com/stevearc/oil.nvim/issues/208)) ([aea896a](https://github.com/stevearc/oil.nvim/commit/aea896a880e294c97a7c395dd8a6c89bdc93c644))
* shorten path when opening files ([#194](https://github.com/stevearc/oil.nvim/issues/194), [#197](https://github.com/stevearc/oil.nvim/issues/197)) ([3275996](https://github.com/stevearc/oil.nvim/commit/3275996ce65f142d0e96b9fc2658f94e5bd43ad5))
* shorten path when opening files ([#194](https://github.com/stevearc/oil.nvim/issues/194)) ([6cbc8d7](https://github.com/stevearc/oil.nvim/commit/6cbc8d725d3964cb08d679774db67d41fa002647))

## [2.2.0](https://github.com/stevearc/oil.nvim/compare/v2.1.0...v2.2.0) (2023-09-30)


### Features

* action for opening entry in an external program ([#183](https://github.com/stevearc/oil.nvim/issues/183)) ([96a334a](https://github.com/stevearc/oil.nvim/commit/96a334abeb85a26af87585ec3810116c7cb7d172))
* keymaps can specify mode ([#187](https://github.com/stevearc/oil.nvim/issues/187)) ([977da9a](https://github.com/stevearc/oil.nvim/commit/977da9ac6655b4f52bc26f23f584d9553f419555))
* make gf work in ssh files ([#186](https://github.com/stevearc/oil.nvim/issues/186)) ([ee81363](https://github.com/stevearc/oil.nvim/commit/ee813638d2d042e4b8e6e8ffd00dae438bdbd4ca))


### Bug Fixes

* add busybox support for ssh adapter ([#173](https://github.com/stevearc/oil.nvim/issues/173)) ([a9ceb90](https://github.com/stevearc/oil.nvim/commit/a9ceb90a63955c409b6fbac0f5cfc4c2f43093fd))
* correctly resolve new files when selected ([#179](https://github.com/stevearc/oil.nvim/issues/179)) ([83e4d04](https://github.com/stevearc/oil.nvim/commit/83e4d049228233df1870c92e160effb33e314396))
* don't override FloatTitle highlight ([#189](https://github.com/stevearc/oil.nvim/issues/189)) ([5ced687](https://github.com/stevearc/oil.nvim/commit/5ced687ddd08e1f8df27a23884d516a9b24101fc))
* hide swapfile error when editing file ([#188](https://github.com/stevearc/oil.nvim/issues/188)) ([bfc5a4c](https://github.com/stevearc/oil.nvim/commit/bfc5a4c48f4a53b95648e41d91e49b83fb03e919))

## [2.1.0](https://github.com/stevearc/oil.nvim/compare/v2.0.1...v2.1.0) (2023-09-11)


### Features

* api to sort directory contents ([#169](https://github.com/stevearc/oil.nvim/issues/169)) ([879d280](https://github.com/stevearc/oil.nvim/commit/879d280617045d5a00d7a053e86d51c6c80970be))


### Bug Fixes

* allow converting a file to directory and vice-versa ([#117](https://github.com/stevearc/oil.nvim/issues/117)) ([926ae06](https://github.com/stevearc/oil.nvim/commit/926ae067eb9a79817a455d5ab2dc6f420beb53c0))
* change default winblend for floating window to 0 ([#167](https://github.com/stevearc/oil.nvim/issues/167)) ([7033d52](https://github.com/stevearc/oil.nvim/commit/7033d52db012666b85504fe9a678939e49bc14b7))
* lock cursor to first mutable column ([d4eb4f3](https://github.com/stevearc/oil.nvim/commit/d4eb4f3bbf7770d04070707c947655a5426d7f75))

## [2.0.1](https://github.com/stevearc/oil.nvim/compare/v2.0.0...v2.0.1) (2023-08-26)


### Bug Fixes

* data loss bug when move + delete ([#162](https://github.com/stevearc/oil.nvim/issues/162)) ([f86d494](https://github.com/stevearc/oil.nvim/commit/f86d49446ae344ba3762d5705505aa09c1c1d4ee))

## [2.0.0](https://github.com/stevearc/oil.nvim/compare/v1.1.0...v2.0.0) (2023-08-24)


### ⚠ BREAKING CHANGES

* disable netrw by default ([#155](https://github.com/stevearc/oil.nvim/issues/155))

### Bug Fixes

* actions.terminal supports ssh adapter ([#152](https://github.com/stevearc/oil.nvim/issues/152)) ([0ccf95a](https://github.com/stevearc/oil.nvim/commit/0ccf95ae5d0ea731de8d427304f95d384a0664c4))
* errors when writing files over ssh ([#159](https://github.com/stevearc/oil.nvim/issues/159)) ([bfa0e87](https://github.com/stevearc/oil.nvim/commit/bfa0e8705eb83a0724aed6d5dc9d21aa62a8986b))
* fix flaky test ([9509ae0](https://github.com/stevearc/oil.nvim/commit/9509ae0feed5af04e4652375740a0722f2ee1a64))
* remaining type errors ([8f78079](https://github.com/stevearc/oil.nvim/commit/8f7807946a67b5f1a515946f82251e33651bae29))
* set nomodifiable after BufWritePre in ssh adapter ([#159](https://github.com/stevearc/oil.nvim/issues/159)) ([b61bc9b](https://github.com/stevearc/oil.nvim/commit/b61bc9b701a3cfb05cb6668446b0303cda7435e6))
* sometimes use shell to run trash command ([#99](https://github.com/stevearc/oil.nvim/issues/99)) ([ff62fc2](https://github.com/stevearc/oil.nvim/commit/ff62fc28cd7976e49ddff6897a4f870785187f13))
* ssh adapter supports any system with /bin/sh ([#161](https://github.com/stevearc/oil.nvim/issues/161)) ([ebcd720](https://github.com/stevearc/oil.nvim/commit/ebcd720a0987ed39f943c4a5d32b96d42e9cf695))
* type annotations and type errors ([47c7737](https://github.com/stevearc/oil.nvim/commit/47c77376189e4063b4fcc6dc2c4cfe8ffd72c782))


### Performance Improvements

* tweak uv readdir params for performance ([ffb89bf](https://github.com/stevearc/oil.nvim/commit/ffb89bf416a4883cc12e5ed247885d4700b00a0f))


### Code Refactoring

* disable netrw by default ([#155](https://github.com/stevearc/oil.nvim/issues/155)) ([9d90893](https://github.com/stevearc/oil.nvim/commit/9d90893c377b6b75230e4bad177f8d0103ceafe4))

## [1.1.0](https://github.com/stevearc/oil.nvim/compare/v1.0.0...v1.1.0) (2023-08-09)


### Features

* config to remove icon padding ([#145](https://github.com/stevearc/oil.nvim/issues/145)) ([b24380c](https://github.com/stevearc/oil.nvim/commit/b24380c0e17d21271cc04d94827a07397b9fc4dc))


### Bug Fixes

* directory hijacking when oil is lazy loaded ([#149](https://github.com/stevearc/oil.nvim/issues/149)) ([966eaaa](https://github.com/stevearc/oil.nvim/commit/966eaaadbc4d344660f867e41f6b1252459065b2))
* leave netrw autocmds intact when default_file_explorer = false ([#135](https://github.com/stevearc/oil.nvim/issues/135)) ([789b486](https://github.com/stevearc/oil.nvim/commit/789b486fb5cdc9e31abe9b0569b0e316f9d07bfd))
* opening oil from netrw defaults to netrw directory ([#148](https://github.com/stevearc/oil.nvim/issues/148)) ([887bb4a](https://github.com/stevearc/oil.nvim/commit/887bb4a8b6c9d73db9c34352d5363ee6289f733e))
* previewed buffers are deleted once hidden ([#141](https://github.com/stevearc/oil.nvim/issues/141)) ([eaa20a6](https://github.com/stevearc/oil.nvim/commit/eaa20a6aee7c4df89d80ec8208de63ec2fa4d38a))
* url-escape paths for scp ([#134](https://github.com/stevearc/oil.nvim/issues/134)) ([a5ff72a](https://github.com/stevearc/oil.nvim/commit/a5ff72a8da0df1042ee4c7705c301901062fa6d5))
* use standard Directory highlight group ([#139](https://github.com/stevearc/oil.nvim/issues/139)) ([f180a9f](https://github.com/stevearc/oil.nvim/commit/f180a9ffab24946a933621108144e2901533d583))

## 1.0.0 (2023-06-27)


### ⚠ BREAKING CHANGES

* selecting multiple files only opens buffers, not windows ([#111](https://github.com/stevearc/oil.nvim/issues/111))
* make oil buffers unlisted by default ([#45](https://github.com/stevearc/oil.nvim/issues/45))
* change scp:// urls back to oil-ssh://

### Features

* action to copy path to entry under cursor ([#50](https://github.com/stevearc/oil.nvim/issues/50)) ([6581d76](https://github.com/stevearc/oil.nvim/commit/6581d76a74760be5fcc5ca562d5032dcba7e5d9a))
* action to open entry in new tab ([#52](https://github.com/stevearc/oil.nvim/issues/52)) ([48eec8b](https://github.com/stevearc/oil.nvim/commit/48eec8b7ef67a5d7a50869fedf0ebbc82a8183d7))
* action to open the cmdline with current entry as argument ([#38](https://github.com/stevearc/oil.nvim/issues/38)) ([75b710e](https://github.com/stevearc/oil.nvim/commit/75b710e311104bc51eb5d04d1ac5db5193f7e834))
* add `setup.view_options.is_excluded` ([19ab948](https://github.com/stevearc/oil.nvim/commit/19ab948e25825a1b8823a391b733cc461f3010f7))
* add action to open a terminal ([c6a2e3e](https://github.com/stevearc/oil.nvim/commit/c6a2e3e08f1f70e52bbfff2b52093c779b4f24ed))
* add bug_report template ([23d1ca7](https://github.com/stevearc/oil.nvim/commit/23d1ca7327413973bbf7aee09e9f25b6f887f370))
* add override config option to customize float layout ([#132](https://github.com/stevearc/oil.nvim/issues/132)) ([ac72a8d](https://github.com/stevearc/oil.nvim/commit/ac72a8df4afc1a543624c0eb1ebc0bedeb83c1a6))
* add toggle_float function ([#94](https://github.com/stevearc/oil.nvim/issues/94)) ([82c7068](https://github.com/stevearc/oil.nvim/commit/82c706822bb13a8ea7a21e0e3dccc83eaf40bfbc))
* added command ([af59e7b](https://github.com/stevearc/oil.nvim/commit/af59e7b53df66192d18170e56f018cbc736dd67f))
* API to change config.view.is_hidden_file at runtime ([#69](https://github.com/stevearc/oil.nvim/issues/69)) ([12bea0f](https://github.com/stevearc/oil.nvim/commit/12bea0f6466661b89a6293c090a415ad7a32d4c8))
* builtin support for editing files over ssh ([#27](https://github.com/stevearc/oil.nvim/issues/27)) ([ca4da68](https://github.com/stevearc/oil.nvim/commit/ca4da68aaebaebf5cd68151c2b5ad56e00c06126))
* can cancel out of progress window ([273c2ce](https://github.com/stevearc/oil.nvim/commit/273c2cecbfe3ddc9fc19446f59cc6e7ff8981cf2))
* can minimize the progress window ([f28e634](https://github.com/stevearc/oil.nvim/commit/f28e63460ae23d88ecca8ba7bb4201b682692bee))
* **columns:** Add compatibility with previous versions ([98a186e](https://github.com/stevearc/oil.nvim/commit/98a186e8f9bd12621f988e95e8dbc4c67f0f3167))
* **columns:** Change to use custom icons ([6dc65dc](https://github.com/stevearc/oil.nvim/commit/6dc65dcf83dbd68a031d848dde61d104e6209b0c))
* config for floating preview window ([#74](https://github.com/stevearc/oil.nvim/issues/74)) ([3e1affa](https://github.com/stevearc/oil.nvim/commit/3e1affa6c784ce6911895a63232fa6e1a6ff5b70))
* config function to define which files are hidden ([#58](https://github.com/stevearc/oil.nvim/issues/58)) ([e5acff1](https://github.com/stevearc/oil.nvim/commit/e5acff1b77ff4372c94ace7daec21f93810166f7))
* config option for trashing deleted files ([#99](https://github.com/stevearc/oil.nvim/issues/99)) ([496d60f](https://github.com/stevearc/oil.nvim/commit/496d60fcff7af652e67c217aa82ab8d219a3f54e))
* config option to disable directory hijacking ([#76](https://github.com/stevearc/oil.nvim/issues/76)) ([3d3df74](https://github.com/stevearc/oil.nvim/commit/3d3df74532eaea2b071da03079c3a4c8e4fe5aeb))
* config option to skip the disclaimer ([adff3b9](https://github.com/stevearc/oil.nvim/commit/adff3b91541cde52793e41b34338f1f9cc19b3a6))
* **config:** Add custom icons ([bf20bca](https://github.com/stevearc/oil.nvim/commit/bf20bca78ddae7fd98ba98046014f3b06c8352ce))
* **config:** Change custom icons to columns config ([cb54e03](https://github.com/stevearc/oil.nvim/commit/cb54e034905ea67c7dd20008952203f0f7b4ed08))
* convert oil://path/to/file.lua to normal file path ([#77](https://github.com/stevearc/oil.nvim/issues/77)) ([d7805c7](https://github.com/stevearc/oil.nvim/commit/d7805c77515082d9e287feb010b3132dde838b3d))
* dispatch autocmd when oil buffer finishes rendering ([3ac035e](https://github.com/stevearc/oil.nvim/commit/3ac035e5ac448ce898c9aad7158a47378be4e85a))
* display shortened path as title of floating window ([#12](https://github.com/stevearc/oil.nvim/issues/12)) ([9f7c4d7](https://github.com/stevearc/oil.nvim/commit/9f7c4d74e1fefc7d88ff5094027b447eadecd787))
* expose buf_options in config ([#28](https://github.com/stevearc/oil.nvim/issues/28)) ([997d9cd](https://github.com/stevearc/oil.nvim/commit/997d9cd78a512d940e3a329e2746d20d77285189))
* extension for resession.nvim ([2bca582](https://github.com/stevearc/oil.nvim/commit/2bca582d935b723e67a41ec8c2d00684a3d1fc8a))
* first draft ([fefd6ad](https://github.com/stevearc/oil.nvim/commit/fefd6ad5e48ff5fcd04fa76d1410a65c40376964))
* inform user how to disable netrw ([6b10a36](https://github.com/stevearc/oil.nvim/commit/6b10a366414578022165fb1e2effea6362bf8ced))
* more actions for interacting with preview window ([#41](https://github.com/stevearc/oil.nvim/issues/41)) ([b3c4ff3](https://github.com/stevearc/oil.nvim/commit/b3c4ff340bed8bb88dc87f054334d67e47aae492))
* new action open_cmdline_dir ([#44](https://github.com/stevearc/oil.nvim/issues/44)) ([6c4a3da](https://github.com/stevearc/oil.nvim/commit/6c4a3dafcadec5f6818135e11c27250a9bdcbbff))
* Oil command supports split and vert modifiers ([#116](https://github.com/stevearc/oil.nvim/issues/116)) ([f322209](https://github.com/stevearc/oil.nvim/commit/f322209a4a2b4685adeda5df00b29cdfd64db08e))
* oil.select can close oil buffer afterwards ([#121](https://github.com/stevearc/oil.nvim/issues/121)) ([a465123](https://github.com/stevearc/oil.nvim/commit/a4651236594cd7717c9b75c43ede0ed5fd4a7dc9))
* option to disable all default keymaps ([#16](https://github.com/stevearc/oil.nvim/issues/16)) ([28da68a](https://github.com/stevearc/oil.nvim/commit/28da68ac5ca451a1f882ecc1eb720295e8c8fd51))
* prompt user to save changes before editing moved file/dir ([#93](https://github.com/stevearc/oil.nvim/issues/93)) ([6b05c2e](https://github.com/stevearc/oil.nvim/commit/6b05c2e91378960be7f7e73867112cee0b4a408a))
* restore window view in oil.close() ([#65](https://github.com/stevearc/oil.nvim/issues/65)) ([33ee724](https://github.com/stevearc/oil.nvim/commit/33ee724c2d25358917147718c3b108a90b571e20))
* set filetype='oil_preview' for preview buffer ([a587977](https://github.com/stevearc/oil.nvim/commit/a587977edda67fd6f506da11e55e3c27727df646))
* sort symbolic directory links like directories ([98fcc2d](https://github.com/stevearc/oil.nvim/commit/98fcc2d0d77f16941d5aac2e0dcf4cffd3cf699a))
* support custom trash commands ([#110](https://github.com/stevearc/oil.nvim/issues/110)) ([f535c10](https://github.com/stevearc/oil.nvim/commit/f535c1057c8d7ce2865bfff1881cc99aa726a044))
* update preview window when cursor is moved ([#42](https://github.com/stevearc/oil.nvim/issues/42)) ([6c6b767](https://github.com/stevearc/oil.nvim/commit/6c6b7673af1314dd7c8254a95eb8d331f6b76ac6))
* Use &lt;C-l&gt; to refresh directory ([#7](https://github.com/stevearc/oil.nvim/issues/7)) ([d019d38](https://github.com/stevearc/oil.nvim/commit/d019d38a3ef4926308735a00bd919a5666c464b6))


### Bug Fixes

* add autocmd to augroup ([5e2f1ce](https://github.com/stevearc/oil.nvim/commit/5e2f1ced9fae1b1dfec45f11f42d49ac9e299bc2))
* add WinLeave autocmd to augroup ([6a227e9](https://github.com/stevearc/oil.nvim/commit/6a227e932fb5e5cac9d4c0fef2a500cac047e99e))
* allow calling oil.open() with a url ([be695dc](https://github.com/stevearc/oil.nvim/commit/be695dc3502f8fb052a83720f3a4dd9578cacdf0))
* alternate buffer preservation ([#43](https://github.com/stevearc/oil.nvim/issues/43)) ([4e853ea](https://github.com/stevearc/oil.nvim/commit/4e853eabcb002650096ef78f098253fe12ba3d8f))
* always close keymap help window ([#17](https://github.com/stevearc/oil.nvim/issues/17)) ([7b703b4](https://github.com/stevearc/oil.nvim/commit/7b703b42da815fb280c6fd7b73961c2e87bcff07))
* always enter directory entries as a directory ([0d5db08](https://github.com/stevearc/oil.nvim/commit/0d5db08015d41a0e3da727bf70796f3a4abcfa76))
* another case of incorrect alternate buffers ([#60](https://github.com/stevearc/oil.nvim/issues/60)) ([b36ba91](https://github.com/stevearc/oil.nvim/commit/b36ba91b7a4d05ee43617383f68cf6ed6fc2f08e))
* bad interaction with editorconfig-vim ([7371dd2](https://github.com/stevearc/oil.nvim/commit/7371dd220f1d08789cc225846d8cafed938777e9))
* better behaved lazy loading in autocmds ([7f17648](https://github.com/stevearc/oil.nvim/commit/7f176487052a155d43c6b64ef44b6dd775e94f99))
* block quit if changes during :wq ([#98](https://github.com/stevearc/oil.nvim/issues/98)) ([37cb6be](https://github.com/stevearc/oil.nvim/commit/37cb6be6f6f98c4616ca382ad955c709dc38f39d))
* bug when copying saved win options to split ([#89](https://github.com/stevearc/oil.nvim/issues/89)) ([caa65e5](https://github.com/stevearc/oil.nvim/commit/caa65e5bfcc98a1450f6a5659fe0f4d28a311967))
* catch errors opening preview window ([#113](https://github.com/stevearc/oil.nvim/issues/113)) ([64d2f30](https://github.com/stevearc/oil.nvim/commit/64d2f305d30cec13938aa99f8f13bd84c502e020))
* close floating oil window on WinLeave ([#17](https://github.com/stevearc/oil.nvim/issues/17)) ([0f10485](https://github.com/stevearc/oil.nvim/commit/0f104854dab0b9edc9dd90bb70fdd782568283ef))
* copying symlinks ([dc18d06](https://github.com/stevearc/oil.nvim/commit/dc18d06bcbf02d84ed48cfa250582c0bb7aa6a02))
* detect duplicate filenames in buffer ([bcb99ae](https://github.com/stevearc/oil.nvim/commit/bcb99ae95a349d33dac9ea54dff0f8915e567eec))
* don't close floating windows we didn't open ([#64](https://github.com/stevearc/oil.nvim/issues/64)) ([073ecb3](https://github.com/stevearc/oil.nvim/commit/073ecb3d68580cd131cd30d83163576807172a77))
* don't show preview if there are no changes ([#19](https://github.com/stevearc/oil.nvim/issues/19)) ([6d0b6ac](https://github.com/stevearc/oil.nvim/commit/6d0b6ac43ce368e5d7aca1798339b597ef6c9981))
* double callback in mutator ([0046508](https://github.com/stevearc/oil.nvim/commit/00465089cb4fdf2c9fb491cd63e36ca135ac6291))
* edge case where cursor position was not set ([#37](https://github.com/stevearc/oil.nvim/issues/37)) ([64d7763](https://github.com/stevearc/oil.nvim/commit/64d7763ac69c581bf1c28492994567c05ddff28a))
* edge case where opening a file would delete its contents ([2e95b9d](https://github.com/stevearc/oil.nvim/commit/2e95b9d42467168185cc5a505ef4288de4c5670f))
* edge case where window options were not set ([b8eaf88](https://github.com/stevearc/oil.nvim/commit/b8eaf88c127b7807fa3a8b00be881ab94f5168b3))
* error messages opening terminal in dir ([90acbdb](https://github.com/stevearc/oil.nvim/commit/90acbdbbffcb461bc6de3544bf8b695f7abeb168))
* error when editing a dir, and still missing parent window ([#40](https://github.com/stevearc/oil.nvim/issues/40)) ([a688443](https://github.com/stevearc/oil.nvim/commit/a6884431b0d7adccf9f4756ca543bf175052f742))
* error when float border is 'none' ([#125](https://github.com/stevearc/oil.nvim/issues/125)) ([4ad1627](https://github.com/stevearc/oil.nvim/commit/4ad162756b800fee4542726b48e98125fb5d7913))
* Error when saving blank lines and quitting. ([2bc63f7](https://github.com/stevearc/oil.nvim/commit/2bc63f7059050f6b172be6aea0402e8b177bde58))
* error when use_default_keymaps = false ([#56](https://github.com/stevearc/oil.nvim/issues/56)) ([f1ea6e0](https://github.com/stevearc/oil.nvim/commit/f1ea6e0ad03e1d7b1acad4d0796d39c4a82b3463))
* escape special characters when editing buffer ([#96](https://github.com/stevearc/oil.nvim/issues/96)) ([339ade9](https://github.com/stevearc/oil.nvim/commit/339ade9dc387958c714a98741cda9e722a931410))
* expand terminal path ([20e4ff1](https://github.com/stevearc/oil.nvim/commit/20e4ff1838d384141f6252520ae572a63abff2cd))
* float positioning and width calculation ([#32](https://github.com/stevearc/oil.nvim/issues/32)) ([f8ca564](https://github.com/stevearc/oil.nvim/commit/f8ca5648021ac6a59e016d81be594fa98f0705c2))
* guard against invalid buffer ([#90](https://github.com/stevearc/oil.nvim/issues/90)) ([a9556aa](https://github.com/stevearc/oil.nvim/commit/a9556aa872215f5956062f24064ade55cf2baeb9))
* icon column does nil-check of config ([f6d2102](https://github.com/stevearc/oil.nvim/commit/f6d2102e2b671ffe28029c0b4b0915e625c3f09f))
* ignore errors when unlocking buffers ([e58f347](https://github.com/stevearc/oil.nvim/commit/e58f347c674332d2ece6a0ff6da05cf93bf0f0b9))
* invalid filetype of oil buffer ([#47](https://github.com/stevearc/oil.nvim/issues/47)) ([2b0b938](https://github.com/stevearc/oil.nvim/commit/2b0b9382d77c4a9ff471a999bddb2f9cc945a300))
* more detailed information when ssh connection fails ([#27](https://github.com/stevearc/oil.nvim/issues/27)) ([f5961e7](https://github.com/stevearc/oil.nvim/commit/f5961e731f641206727eaded197e5879694c35f7))
* new oil buffers are nomodifiable during mutation processing ([d631d9f](https://github.com/stevearc/oil.nvim/commit/d631d9fc5a958c7c9ee0717b1fe040a3ec951c63))
* no error if opening file that has swapfile ([a60639d](https://github.com/stevearc/oil.nvim/commit/a60639db358c0b40f9fe297b1f52f3eb62c190c6))
* off-by-one errors in tests ([6062ad6](https://github.com/stevearc/oil.nvim/commit/6062ad6737d36e8a1cc10696cf5e870057eba20c))
* oil buffers load properly after loading a session ([#29](https://github.com/stevearc/oil.nvim/issues/29)) ([bb5201c](https://github.com/stevearc/oil.nvim/commit/bb5201c9cd422e7b145699b5dccd8e70e4630a9d))
* oil buffers remain unmodified after saving changes ([931453f](https://github.com/stevearc/oil.nvim/commit/931453fc09085c09537295c991c66637869e97e1))
* oil can open when terminal is focused ([#51](https://github.com/stevearc/oil.nvim/issues/51)) ([0e53d40](https://github.com/stevearc/oil.nvim/commit/0e53d402219c74d351fffb18d97d7e350f87bfd8))
* oil loses track of buffers after refresh ([9871ca9](https://github.com/stevearc/oil.nvim/commit/9871ca9737d4ffd68b40ad68b8f89848d835b286))
* oil-ssh assume target machine's locales ([c72bcb4](https://github.com/stevearc/oil.nvim/commit/c72bcb45b2e824150cbf356c2e13e37d6863369b))
* oil.close doesn't error when no other buffers exist ([#79](https://github.com/stevearc/oil.nvim/issues/79)) ([4b05ebd](https://github.com/stevearc/oil.nvim/commit/4b05ebdf202bf61ce240f40558822fe5564d02ea))
* oil.close() sometimes closes window too ([#64](https://github.com/stevearc/oil.nvim/issues/64)) ([d48fa09](https://github.com/stevearc/oil.nvim/commit/d48fa09c82b133d384c84c98725b722fd06f38af))
* opening with lowercase drive letters ([29808f2](https://github.com/stevearc/oil.nvim/commit/29808f273c817543d049f6d2541a550e233de4ff))
* preserve alternate buffer when using floating window ([#20](https://github.com/stevearc/oil.nvim/issues/20)) ([d8a1e7c](https://github.com/stevearc/oil.nvim/commit/d8a1e7ca4e599c43dda1849a66b19d9fbff12310))
* preserve the alternate buffer ([#20](https://github.com/stevearc/oil.nvim/issues/20)) ([e4c4110](https://github.com/stevearc/oil.nvim/commit/e4c411002272d6eed159afdf4cae2e74dc7fc813))
* prevent double-delete autocmd ids ([#97](https://github.com/stevearc/oil.nvim/issues/97)) ([4107784](https://github.com/stevearc/oil.nvim/commit/41077847b98d6d3b88b6d31864bb20a664e88574))
* preview window renders on top of floating window title ([#72](https://github.com/stevearc/oil.nvim/issues/72)) ([383971b](https://github.com/stevearc/oil.nvim/commit/383971b0cfd8248ec3d00d4a3154d69ebd5e394e))
* renaming buffers doesn't interfere with directory hijack ([#25](https://github.com/stevearc/oil.nvim/issues/25)) ([b4ccc16](https://github.com/stevearc/oil.nvim/commit/b4ccc16944a3678558ab8f73fa803409b38f58d6))
* reposition preview window if vim is resized ([8cbb104](https://github.com/stevearc/oil.nvim/commit/8cbb104e76efee35ca8125da8d441c395e568e23))
* reposition progress window if vim is resized ([092f4b1](https://github.com/stevearc/oil.nvim/commit/092f4b1c7c14633cd58659dc93eed92c5c26810c))
* restore modified state of current buffer if actions are canceled ([#6](https://github.com/stevearc/oil.nvim/issues/6)) ([2e6d684](https://github.com/stevearc/oil.nvim/commit/2e6d68453f98d3d69cd5c36577f7a381aa7399f3))
* restore window options on split windows ([#36](https://github.com/stevearc/oil.nvim/issues/36)) ([fb69775](https://github.com/stevearc/oil.nvim/commit/fb697752b28ecc41ecaab4206b41e61496ab87f2))
* selecting multiple files only opens buffers, not windows ([#111](https://github.com/stevearc/oil.nvim/issues/111)) ([393f0dc](https://github.com/stevearc/oil.nvim/commit/393f0dcf82f04de597e194ec120d8cbe6fe212a8))
* set alternate buffer when inside oil ([#60](https://github.com/stevearc/oil.nvim/issues/60)) ([f1131b5](https://github.com/stevearc/oil.nvim/commit/f1131b5e90ce5cdbbd122e298d62726dfa4b808a))
* set bufhidden = 'hide' by default ([#104](https://github.com/stevearc/oil.nvim/issues/104)) ([19563c3](https://github.com/stevearc/oil.nvim/commit/19563c365800ab519e46a08a0aa59d5677b329b6))
* shortened path for current directory is '.' ([7649866](https://github.com/stevearc/oil.nvim/commit/76498666500c2aee94fd07366222d76c4d13ee2f))
* silence doautocmd errors ([9dbf18a](https://github.com/stevearc/oil.nvim/commit/9dbf18a524df1a563b2a8f46b14645aa47022f9e))
* some autocmds skipped when opening files from oil ([#120](https://github.com/stevearc/oil.nvim/issues/120)) ([61f8655](https://github.com/stevearc/oil.nvim/commit/61f8655e03dea805bb77aad5b4ca99d1176510b7))
* ssh adapter handles character and block files ([aa68ec4](https://github.com/stevearc/oil.nvim/commit/aa68ec4d988be3c898341f65f54c1620986240dd))
* stop using vim.wo to set window options ([6f8bf06](https://github.com/stevearc/oil.nvim/commit/6f8bf067c09e96d6bff548b5e6addb6d9c25a678))
* symbolic link target parsing fails if it has a trailing slash ([#131](https://github.com/stevearc/oil.nvim/issues/131)) ([9be36a6](https://github.com/stevearc/oil.nvim/commit/9be36a648889c37d11bc65e8422049dc33dd6a3f))
* unexpected behavior from BufReadPost autocmds ([716dd8f](https://github.com/stevearc/oil.nvim/commit/716dd8f9cf1ff2b9cda03497025612ce3c366307))
* unlock buffers if we cancel the actions ([#4](https://github.com/stevearc/oil.nvim/issues/4)) ([0d6ee14](https://github.com/stevearc/oil.nvim/commit/0d6ee144d210b8627e9c3fd98dc32ec3e9360aa2))
* update preview window in-place ([#74](https://github.com/stevearc/oil.nvim/issues/74)) ([57451c5](https://github.com/stevearc/oil.nvim/commit/57451c517d96ad856ed418203729f5d3cb200de6))
* url formatting errors when ssh connection specifies port ([9a03af7](https://github.com/stevearc/oil.nvim/commit/9a03af7cb752f46b9efa85fc132d9281f5672f23))
* warning when :tabnew from oil buffer ([#40](https://github.com/stevearc/oil.nvim/issues/40)) ([73c6fcf](https://github.com/stevearc/oil.nvim/commit/73c6fcf519afbd99b8cef00d8663bed20f87a1df))


### Code Refactoring

* change scp:// urls back to oil-ssh:// ([3164537](https://github.com/stevearc/oil.nvim/commit/31645370a105e59270634ec14665149e919f7432))
* make oil buffers unlisted by default ([#45](https://github.com/stevearc/oil.nvim/issues/45)) ([1d54819](https://github.com/stevearc/oil.nvim/commit/1d548190cf4a032d0354c0bf84d042a618152769))
