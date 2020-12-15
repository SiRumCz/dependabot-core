require "dependabot/clients/github_with_retries"

module Dependabot
  class RemIssueCreator
    class Github
      attr_reader :source, :credentials, :issue_title, :issue_description,
                  :labels

      def initialize(source:, credentials:, issue_title:, issue_description:,
                     labels:[])
        @source            = source
        @credentials       = credentials
        @issue_title       = issue_title
        @issue_description = issue_description
        @labels            = labels
      end

      def github_client_for_source
        @github_client_for_source ||=
          Dependabot::Clients::GithubWithRetries.for_source(
            source: source,
            credentials: credentials
          )
      end

      def create
        github_client_for_source.create_issue(
          source.repo,
          issue_title,
          issue_description,
          labels: labels.join(",")
        )
      rescue Octokit::UnprocessableEntity
    #     return handle_pr_creation_error(e) if e.message.include? "Error summary"

    #     # Sometimes PR creation fails with no details (presumably because the
    #     # details are internal). It doesn't hurt to retry in these cases, in
    #     # case the cause is a race.
        retrying_issue_creation ||= false
        raise if retrying_issue_creation

        retrying_issue_creation = true
        retry
      end
    end
  end
end