# Generic CLI task runner

Run all executables local to you project behind namespace (`zc`).

## Example

Consider this example project where scripts, tasks and command line utilities
is scattered over time through out the project, or you just keep
the scripts semantically separated, and then have to fight your way
through the directory structure to find the scripts in order to invoke them.

`zc` helps keeping your local project tools, scripts and utilities easily
accessible at all times.

```
/~project
  |-bin
    |-pack.js (chmod +x)
  |-node_modules
    |-.bin
      | webpack
  |-scripts
    |-lint.sh (chmod +x)
    |-test.sh
  |-.env (ZC_NODE_MODULE=true)
```

```shell
~project $ zc lint
Running linter

~project $ zc test
Unable to find any tasks matching "test"

~project/deeply/nested/structure $ zc pack
Packing everything

~project $ zc webpack
Running webpack...
```

## Installation

via npm

```shell
$ sudo npm install -g @zeroconf/cli
```

or yarn

```shell
$ sudo yarn global add @zeroconf/cli
```

### Configuration

There are minor tweaks that can be done via an .env file (dotenv) in the root
of you project.

The project path can be configured via `PROJECT_PATH` or `ZC_PROJECT_PATH`
variables. `ZC_PROJECT_PATH` takes precedence over `PROJECT_PATH`.
However if no project path is configured, `zc` will try make a guess where your project root is located.

| Environment variable  | Default value                                                                                                                    | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| :-------------------- | :------------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PROJECT_PATH`        | `""`                                                                                                                             | This value controls where `zc` consider the root path of the project is, thus where to look for executables from. It can be superseded by `ZC_PROJECT_PATH`.                                                                                                                                                                                                                                                                                                                                                                                                            |
| `ZC_PROJECT_PATH`     | `$PROJECT_PATH`                                                                                                                  | Overrides `PROJECT_PATH`. If neither `PROJECT_PATH` nor `ZC_PROJECT_PATH` is set, `zc` will traverse from current working directory and traverse towards `/` (root) and try to guess where the project root will be. Things such as `.git` and `node_modules` directories or `.env` and `package.json` files are considered. More will probably come later. If the guessing mechanism isn't sufficient place a `.env` file in the root of you project and use the `PROJECT_PATH` or `ZC_PROJECT_PATH` variables to control where `zc` should look for executables from. |
| `ZC_BIN_PATHS`        | `("$ZC_PROJECT_PATH/.bin" "$ZC_PROJECT_PATH/bin" "$ZC_PROJECT_PATH/scripts" "$ZC_PROJECT_PATH/tasks" "$ZC_PROJECT_PATH/tools" )` | The directories to look for executables within. NB! per default the task finder mechanism won't recursive inside the `ZC_BIN_PATHS`, this behavior can however be altered by setting `ZC_BIN_PATH_RECURSE=true`.                                                                                                                                                                                                                                                                                                                                                        |
| `ZC_BIN_PATH_RECURSE` | `false`                                                                                                                          | Controlling whether or not the task finder mechanism should look for tasks recursively from the `ZC_BIN_PATHS`.                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
