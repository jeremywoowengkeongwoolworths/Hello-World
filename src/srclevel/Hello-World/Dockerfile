FROM wlxacrbaseimages.azurecr.io/aspnet:8.0

WORKDIR /app
COPY /out .

USER app
ENTRYPOINT ["dotnet", "./Hello-World.dll"]