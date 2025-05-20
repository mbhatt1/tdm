package controller

import (
	"context"
	"fmt"
	"time"

	"github.com/mbhatt/tvm/pkg/apis/vvm/v1alpha1"
	"github.com/mbhatt/tvm/pkg/flintlock"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/client-go/tools/record"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	logf "sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/manager"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
	"sigs.k8s.io/controller-runtime/pkg/source"
)

var log = logf.Log.WithName("controller_microvm")

// Add creates a new MicroVM Controller and adds it to the Manager
func Add(mgr manager.Manager, flintlockEndpoint string) error {
	return add(mgr, newReconciler(mgr, flintlockEndpoint))
}

// newReconciler returns a new reconcile.Reconciler
func newReconciler(mgr manager.Manager, flintlockEndpoint string) reconcile.Reconciler {
	flintlockClient, err := flintlock.NewClient(flintlockEndpoint)
	if err != nil {
		log.Error(err, "Failed to create Flintlock client")
		return nil
	}

	return &ReconcileMicroVM{
		client:          mgr.GetClient(),
		scheme:          mgr.GetScheme(),
		recorder:        mgr.GetEventRecorderFor("microvm-controller"),
		flintlockClient: flintlockClient,
	}
}

// add adds a new Controller to mgr with r as the reconcile.Reconciler
func add(mgr manager.Manager, r reconcile.Reconciler) error {
	// Create a new controller
	c, err := controller.New("microvm-controller", mgr, controller.Options{Reconciler: r})
	if err != nil {
		return err
	}

	// Watch for changes to MicroVM
	err = c.Watch(&source.Kind{Type: &v1alpha1.MicroVM{}}, &handler.EnqueueRequestForObject{})
	if err != nil {
		return err
	}

	return nil
}

// ReconcileMicroVM reconciles a MicroVM object
type ReconcileMicroVM struct {
	client          client.Client
	scheme          *runtime.Scheme
	recorder        record.EventRecorder
	flintlockClient *flintlock.Client
}

// Reconcile reads that state of the cluster for a MicroVM object and makes changes based on the state read
func (r *ReconcileMicroVM) Reconcile(ctx context.Context, request reconcile.Request) (reconcile.Result, error) {
	reqLogger := log.WithValues("Request.Namespace", request.Namespace, "Request.Name", request.Name)
	reqLogger.Info("Reconciling MicroVM")

	// Fetch the MicroVM instance
	instance := &v1alpha1.MicroVM{}
	err := r.client.Get(ctx, request.NamespacedName, instance)
	if err != nil {
		if errors.IsNotFound(err) {
			// Request object not found, could have been deleted after reconcile request.
			// Return and don't requeue
			return reconcile.Result{}, nil
		}
		// Error reading the object - requeue the request.
		return reconcile.Result{}, err
	}

	// Check if the MicroVM is being deleted
	if !instance.ObjectMeta.DeletionTimestamp.IsZero() {
		return r.handleDelete(ctx, instance)
	}

	// Handle different states
	switch instance.Status.State {
	case "":
		// New MicroVM, initialize it
		return r.handleNew(ctx, instance)
	case v1alpha1.MicroVMStateCreating:
		// MicroVM is being created, check its status
		return r.handleCreating(ctx, instance)
	case v1alpha1.MicroVMStateRunning:
		// MicroVM is running, update its status
		return r.handleRunning(ctx, instance)
	case v1alpha1.MicroVMStateError:
		// MicroVM is in error state, try to recover
		return r.handleError(ctx, instance)
	case v1alpha1.MicroVMStateDeleted:
		// MicroVM is deleted, clean up
		return reconcile.Result{}, nil
	default:
		// Unknown state
		instance.Status.State = v1alpha1.MicroVMStateError
		instance.Status.Error = fmt.Sprintf("Unknown state: %s", instance.Status.State)
		err = r.client.Status().Update(ctx, instance)
		return reconcile.Result{}, err
	}
}

// handleNew handles a new MicroVM
func (r *ReconcileMicroVM) handleNew(ctx context.Context, instance *v1alpha1.MicroVM) (reconcile.Result, error) {
	// Update status to Creating
	instance.Status.State = v1alpha1.MicroVMStateCreating
	instance.Status.LastActivity = &metav1.Time{Time: time.Now()}
	err := r.client.Status().Update(ctx, instance)
	if err != nil {
		return reconcile.Result{}, err
	}

	// Create the MicroVM using Flintlock
	err = r.flintlockClient.CreateMicroVM(ctx, instance)
	if err != nil {
		instance.Status.State = v1alpha1.MicroVMStateError
		instance.Status.Error = err.Error()
		r.client.Status().Update(ctx, instance)
		return reconcile.Result{}, err
	}

	// Requeue to check status
	return reconcile.Result{RequeueAfter: 5 * time.Second}, nil
}

// handleCreating handles a MicroVM that is being created
func (r *ReconcileMicroVM) handleCreating(ctx context.Context, instance *v1alpha1.MicroVM) (reconcile.Result, error) {
	// Update status from Flintlock
	err := r.flintlockClient.UpdateMicroVMStatus(instance)
	if err != nil {
		instance.Status.State = v1alpha1.MicroVMStateError
		instance.Status.Error = err.Error()
		r.client.Status().Update(ctx, instance)
		return reconcile.Result{}, err
	}

	// Update the instance
	instance.Status.LastActivity = &metav1.Time{Time: time.Now()}
	err = r.client.Status().Update(ctx, instance)
	if err != nil {
		return reconcile.Result{}, err
	}

	// If still creating, requeue
	if instance.Status.State == v1alpha1.MicroVMStateCreating {
		return reconcile.Result{RequeueAfter: 5 * time.Second}, nil
	}

	return reconcile.Result{}, nil
}

// handleRunning handles a running MicroVM
func (r *ReconcileMicroVM) handleRunning(ctx context.Context, instance *v1alpha1.MicroVM) (reconcile.Result, error) {
	// Update status from Flintlock
	err := r.flintlockClient.UpdateMicroVMStatus(instance)
	if err != nil {
		instance.Status.State = v1alpha1.MicroVMStateError
		instance.Status.Error = err.Error()
		r.client.Status().Update(ctx, instance)
		return reconcile.Result{}, err
	}

	// Update the instance
	instance.Status.LastActivity = &metav1.Time{Time: time.Now()}
	err = r.client.Status().Update(ctx, instance)
	if err != nil {
		return reconcile.Result{}, err
	}

	// Requeue periodically to update status
	return reconcile.Result{RequeueAfter: 30 * time.Second}, nil
}

// handleError handles a MicroVM in error state
func (r *ReconcileMicroVM) handleError(ctx context.Context, instance *v1alpha1.MicroVM) (reconcile.Result, error) {
	// For now, just log the error
	log.Error(fmt.Errorf(instance.Status.Error), "MicroVM in error state", "namespace", instance.Namespace, "name", instance.Name)

	// Requeue to check if it recovers
	return reconcile.Result{RequeueAfter: 30 * time.Second}, nil
}

// handleDelete handles a MicroVM that is being deleted
func (r *ReconcileMicroVM) handleDelete(ctx context.Context, instance *v1alpha1.MicroVM) (reconcile.Result, error) {
	// Delete the MicroVM using Flintlock
	if instance.Status.VMID != "" {
		err := r.flintlockClient.DeleteMicroVM(ctx, instance.Status.VMID)
		if err != nil {
			log.Error(err, "Failed to delete MicroVM", "namespace", instance.Namespace, "name", instance.Name)
			// Continue with deletion even if Flintlock fails
		}
	}

	// Update status to Deleted
	instance.Status.State = v1alpha1.MicroVMStateDeleted
	instance.Status.LastActivity = &metav1.Time{Time: time.Now()}
	err := r.client.Status().Update(ctx, instance)
	if err != nil && !errors.IsNotFound(err) {
		return reconcile.Result{}, err
	}

	return reconcile.Result{}, nil
}
