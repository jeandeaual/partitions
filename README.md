# LilyPond Partitions

![deploy](https://github.com/jeandeaual/partitions/workflows/deploy/badge.svg)
![test](https://github.com/jeandeaual/partitions/workflows/test/badge.svg)
![lint](https://github.com/jeandeaual/partitions/workflows/lint/badge.svg)

Generates a [website](https://jeandeaual.github.io/partitions)
and [OPDS feed](https://jeandeaual.github.io/partitions/opds/root.xml)
listing the LilyPond partitions hosted on my GitHub account.

## Prerequisites

* [Ruby 2.7](https://www.ruby-lang.org/en/downloads/) needs to be installed
* Install the Ruby dependencies (the first line is optional):
    ```sh
    BUNDLE_WITHOUT=development bundle install
    ```
* Set the environment variables `GITHUB_USER` and `GITHUB_TOKEN`:
    ```sh
    export GITHUB_USER="{{username}}"
    export GITHUB_TOKEN="{{token}}"
    ```
* Download the PDFs from the repositories:
    ```sh
    ./download_pdfs.rb
    ```
* Generate the OPDS feeds:
    ```sh
    ./generate_opds.rb
    ```

### Running Jekyll Locally

```text
cd site
bundle exec jekyll serve --livereload
```

### Building the Jekyll Site

```text
cd site
bundle exec jekyll build
```
