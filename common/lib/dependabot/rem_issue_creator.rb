# frozen_string_literal: true

module Dependabot
  class RemIssueCreator

    require "dependabot/rem_issue_creator/github"

    class RepoNotFound < StandardError; end
    class RepoArchived < StandardError; end
    class RepoDisabled < StandardError; end

    attr_reader :source, :credentials, :custom_labels, :lockfile,
                :package_json, :metric, :rem_api, :commit

    def initialize(source:, credentials:, custom_labels:[], lockfile:, package_json:, 
                   metric:, rem_api:, commit:)
      @source        = source
      @credentials   = credentials
      @custom_labels = custom_labels
      @lockfile      = lockfile
      @package_json  = package_json
      @metric        = metric
      @rem_api       = rem_api
      @commit        = commit
    end

    def create
      if source.provider == "github"
        github_creator.create
      # when "gitlab" then gitlab_creator.create
      # when "azure" then azure_creator.create
      # when "codecommit" then codecommit_creator.create
      else 
        raise "Unsupported provider #{source.provider}"
      end
    end

    private

    def github_creator
      Github.new(
        source: source,
        credentials: credentials,
        issue_title: issue_title,
        issue_description: build_issue_description,
        labels: custom_labels
      )
    end

    def retrieve_rem_urls
      return nil if rem_api.nil? or rem_api.empty?
      return nil if lockfile.nil? or package_json.nil?

      body = {}
      body.compare_by_identity
      body['package_json'] = package_json.content
      body['lockfile'] = lockfile.content
      body['lockfile'] = lockfile.content
      if metric
        body['highlight_metric'] = metric
      end
      
      resp = HTTParty.post(
        rem_api, 
        body: body, 
        timeout: 1000, 
        headers: { 
          "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.108 Safari/537.36" 
          }
        )
      if resp.success?
        return resp.parsed_response
      else
        raise "rem api #{rem_api} failed -- #{resp.response}"
      end
    end

    def issue_title
      "Ripple-Effect of Metrics dependency graph on branch: #{source.branch}, directory: #{source.directory}"
    end

    def build_issue_description
      urls = retrieve_rem_urls
      msg = ""
      if commit
        msg += "REM dependency graph built on commit [#{commit[0..6]}](https://#{source.hostname+'/'+source.repo+'/tree/'+commit})\n"
      end
      if urls['issue_link']
        msg += "![REM](#{urls['issue_link']})"
      end
      if urls['live_link']
        msg += "[click here to see live view](#{urls['live_link']})"
      end
      msg
    end
  end
end