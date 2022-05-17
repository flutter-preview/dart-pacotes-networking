import 'dart:async';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:networking/networking.dart';

/// Base networking client for communicating with external HTTP Web APIs.
/// Internally uses Dart [http] client library and requires one instance of it
/// to start the client. This is done to allow mocking of networking requests.
///
/// Strives to be a functional networking client, removing
/// side effects without throwing
/// errors. Instead it encapsulates them in a Failure monad.
///
/// Also requires the injection of the base URL which requests are originated.
///
/// Permits the timeout of a request after a defined duration.
/// The default timeout duration is 5 minutes.
///
class NetworkingClient {
  final Uri baseUrl;

  final http.Client httpClient;

  final Duration timeoutDuration;

  const NetworkingClient({
    required this.baseUrl,
    required this.httpClient,
    this.timeoutDuration = const Duration(minutes: 5),
  });

  Future<Either<Response, RequestError>> get({
    required final String endpoint,
    final Map<String, String>? headers,
    final Map<String, dynamic>? queryParameters,
  }) {
    return send(
      request: Request(
        verb: HttpVerb.get,
        uri: resolveUri(
          baseUrl: baseUrl,
          endpoint: endpoint,
          queryParameters: queryParameters,
        ),
        headers: headers,
      ),
    );
  }

  Future<Either<Response, RequestError>> post({
    required final String endpoint,
    final ContentType contentType = ContentType.json,
    final String? data,
    final Map<String, String>? headers,
    final Map<String, dynamic>? queryParameters,
  }) {
    return send(
      request: Request(
        verb: HttpVerb.post,
        uri: resolveUri(
          baseUrl: baseUrl,
          endpoint: endpoint,
          queryParameters: queryParameters,
        ),
        contentType: contentType,
        data: data,
        headers: headers,
      ),
    );
  }

  Future<Either<Response, RequestError>> put({
    required final String endpoint,
    final ContentType contentType = ContentType.json,
    final String? data,
    final Map<String, String>? headers,
    final Map<String, dynamic>? queryParameters,
  }) {
    return send(
      request: Request(
        verb: HttpVerb.put,
        uri: resolveUri(
          baseUrl: baseUrl,
          endpoint: endpoint,
          queryParameters: queryParameters,
        ),
        contentType: contentType,
        data: data,
        headers: headers,
      ),
    );
  }

  Future<Either<Response, RequestError>> patch({
    required final String endpoint,
    final ContentType contentType = ContentType.json,
    final String? data,
    final Map<String, String>? headers,
    final Map<String, dynamic>? queryParameters,
  }) {
    return send(
      request: Request(
        verb: HttpVerb.patch,
        uri: resolveUri(
          baseUrl: baseUrl,
          endpoint: endpoint,
          queryParameters: queryParameters,
        ),
        contentType: contentType,
        data: data,
        headers: headers,
      ),
    );
  }

  Future<Either<Response, RequestError>> delete({
    required final String endpoint,
    final Map<String, String>? headers,
    final Map<String, dynamic>? queryParameters,
  }) {
    return send(
      request: Request(
        verb: HttpVerb.delete,
        uri: resolveUri(
          baseUrl: baseUrl,
          endpoint: endpoint,
          queryParameters: queryParameters,
        ),
        headers: headers,
      ),
    );
  }

  Future<Either<Response, RequestError>> send({
    required final Request request,
  }) async {
    try {
      final httpRequest = http.Request(request.verb.value(), request.uri);

      httpRequest.headers
        ..addAll(request.headers)
        ..addAll(
          {'Content-Type': request.contentType.value()},
        );

      httpRequest.body = request.data;

      final httpResponse =
          await httpClient.send(httpRequest).timeout(timeoutDuration);

      final statusCode = httpResponse.statusCode;

      final contentType = ContentTypeExtension.of(
        httpResponse.headers['content-type'],
      );

      final body = await httpResponse.stream.toBytes();

      final headers = httpResponse.headers;

      if ((statusCode - 200) < 200) {
        switch (contentType) {
          case ContentType.jpeg:
            return Left(
              JpegImageResponse(
                body: body,
                statusCode: statusCode,
                headers: headers,
              ),
            );
          case ContentType.json:
            return Left(
              JsonResponse(
                body: body,
                statusCode: statusCode,
                headers: headers,
              ),
            );
          case ContentType.png:
            return Left(
              PngImageResponse(
                body: body,
                statusCode: statusCode,
                headers: headers,
              ),
            );
          case ContentType.plainText:
            return Left(
              PlainTextResponse(
                body: body,
                statusCode: statusCode,
                headers: headers,
              ),
            );
          default:
            return Left(
              BinaryResponse(
                body: body,
                statusCode: statusCode,
                headers: headers,
              ),
            );
        }
      } else {
        return Left(
          ErrorResponse(
            contentType: contentType,
            body: body,
            statusCode: statusCode,
            headers: headers,
          ),
        );
      }
    } on TimeoutException catch (error, stackTrace) {
      return Right(
        TimeoutError(cause: error.message ?? 'timeout', stackTrace: stackTrace),
      );
    } on SocketException catch (error, stackTrace) {
      return Right(
        NoInternetConnectionError(cause: error.message, stackTrace: stackTrace),
      );
    } on Exception catch (error, stackTrace) {
      return Right(
        UnknownError(cause: error.toString(), stackTrace: stackTrace),
      );
    }
  }

  @visibleForTesting
  Uri resolveUri({
    required final Uri baseUrl,
    required final String endpoint,
    final Map<String, dynamic>? queryParameters,
  }) {
    return baseUrl.resolveUri(
      Uri(
        path: '${baseUrl.path}/$endpoint',
        queryParameters: queryParameters ?? {},
      ),
    );
  }
}
