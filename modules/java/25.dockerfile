# Install Java 25 via SDKMAN as agent user
RUN curl -s "https://get.sdkman.io?rcupdate=false" | bash && \
    echo 'source "$HOME/.sdkman/bin/sdkman-init.sh"' >> ~/.bashrc && \
    echo 'source "$HOME/.sdkman/bin/sdkman-init.sh"' >> ~/.zshrc && \
    bash -c "source $HOME/.sdkman/bin/sdkman-init.sh && \
        sdk install java 25-tem && \
        sdk install gradle && \
        sdk install maven"
